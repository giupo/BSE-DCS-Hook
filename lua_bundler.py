#!/usr/bin/env python3
"""
lua_bundler.py - genera un bundle Lua autocontenuto usando package.preload

Esempio:
  python3 lua_bundler.py --project-root src --output bundle.lua --main main.lua

Opzioni utili:
  --project-root : cartella radice contenente i file .lua (default: src)
  --output       : file di output (default: bundle.lua)
  --main         : nome (relativo a project-root) del file main (default: main.lua)
  --force        : sovrascrive output se esiste
  --verbose      : output verboso
  --exclude      : pattern da escludere (può ripetere)
"""

from __future__ import annotations
import argparse
import os
import sys
import re
from typing import List, Tuple, Dict, Optional

RETURN_TOPLEVEL_RE = re.compile(r'^\s*return\b', re.MULTILINE)
MODULE_REQUIRE_RE = re.compile(r'require\s*\(\s*["\']([a-zA-Z0-9_.]+)["\']\s*\)')

def find_lua_files(root: str, exclude: List[str], verbose: bool=False) -> List[str]:
    lua_files = []
    for dirpath, _, filenames in os.walk(root):
        for fname in filenames:
            if not fname.endswith('.lua'):
                continue
            rel = os.path.relpath(os.path.join(dirpath, fname), root)
            if any(rel.startswith(e) for e in exclude):
                if verbose:
                    print(f"[skip] excluded: {rel}")
                continue
            lua_files.append(os.path.join(dirpath, fname))
    return sorted(lua_files)

def path_to_module_name(root: str, path: str) -> str:
    rel = os.path.relpath(path, root)
    if rel.endswith('.lua'):
        rel = rel[:-4]
    # normalize separators to dot
    return rel.replace(os.sep, '.')

def read_file(path: str) -> str:
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def has_toplevel_return(source: str) -> bool:
    # semplice check: cerca "return" che non sia commentato: this is heuristic but works well
    # we look for a 'return' at start of a line (optionally preceded by whitespace)
    return bool(RETURN_TOPLEVEL_RE.search(source))

def safe_module_return_name(module_name: str) -> str:
    # last piece, e.g. net.udp -> udp
    return module_name.split('.')[-1]

def make_preload_entry(module_name: str, source: str, add_return_if_missing: bool=True) -> str:
    """Ritorna il testo da inserire in package.preload[...] per questo modulo."""
    lines = []
    lines.append(f'package.preload["{module_name}"] = function()')
    # Indentare il codice del modulo di 4 spazi
    for line in source.splitlines():
        lines.append('    ' + line)
    # Se non c'è un return top-level e l'opzione è abilitata, proviamo ad aggiungere `return <last_piece>`
    if add_return_if_missing and not has_toplevel_return(source):
        last_piece = safe_module_return_name(module_name)
        # Aggiungiamo solo se ultima parola plausibile (evitiamo di generare codice errato)
        lines.append(f'    return {last_piece}')
    lines.append('end\n')
    return '\n'.join(lines)

def generate_bundle(project_root: str,
                    output_file: str,
                    main_file: str,
                    force: bool=False,
                    exclude: Optional[List[str]]=None,
                    verbose: bool=False) -> None:
    if exclude is None:
        exclude = []
    if not os.path.isdir(project_root):
        raise SystemExit(f"project root non trovato: {project_root}")
    if os.path.exists(output_file) and not force:
        raise SystemExit(f"output file esistente: {output_file} (usa --force per sovrascrivere)")

    lua_files = find_lua_files(project_root, exclude, verbose=verbose)
    # Escludiamo main file dalla lista dei moduli
    main_path = os.path.normpath(os.path.join(project_root, main_file))
    modules = []
    for p in lua_files:
        np = os.path.normpath(p)
        if os.path.abspath(np) == os.path.abspath(main_path):
            if verbose:
                print(f"[info] main rilevato e escluso dai moduli: {p}")
            continue
        modules.append(p)

    module_map: Dict[str, str] = {}  # module_name -> file_path
    duplicates: Dict[str, List[str]] = {}
    for path in modules:
        modname = path_to_module_name(project_root, path)
        if modname in module_map:
            duplicates.setdefault(modname, []).append(path)
        else:
            module_map[modname] = path

    if duplicates:
        print("[warning] moduli duplicati trovati (stesso nome modulo, file diversi):")
        for mod, paths in duplicates.items():
            print(f"  {mod}:")
            print(f"    {module_map[mod]}")
            for p in paths:
                print(f"    {p}")
        print("Il primo file trovato verrà usato. Se vuoi un comportamento diverso, rinomina i file.")
        # non abortiamo; procediamo con il primo trovato

    # Ordiniamo i moduli per nome per avere output deterministico
    sorted_modules = sorted(module_map.items(), key=lambda kv: kv[0])

    with open(output_file, 'w', encoding='utf-8') as out:
        out.write("-- BUNDLE AUTOGENERATO\n")
        out.write("-- project_root: " + os.path.abspath(project_root) + "\n\n")

        for module_name, path in sorted_modules:
            if verbose:
                print(f"[include] {module_name} <- {path}")
            src = read_file(path)
            entry = make_preload_entry(module_name, src, add_return_if_missing=True)
            out.write(entry)
            out.write("\n")

        # append main file raw (non wrapped)
        if not os.path.exists(main_path):
            raise SystemExit(f"main file non trovato: {main_path}")
        out.write("-- MAIN\n")
        main_src = read_file(main_path)
        out.write(main_src)

    if verbose:
        print(f"[done] bundle scritto in {output_file}")

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Lua bundler: genera un unico file con package.preload per tutti i moduli")
    p.add_argument("--project-root", "-p", default="src", help="cartella radice contenente i file .lua")
    p.add_argument("--output", "-o", default="bundle.lua", help="file di output generato")
    p.add_argument("--main", "-m", default="main.lua", help="nome relativo del main file dentro project-root")
    p.add_argument("--force", "-f", action="store_true", help="sovrascrivi output se esiste")
    p.add_argument("--verbose", "-v", action="store_true", help="stampa messaggi verbosi")
    p.add_argument("--exclude", "-e", action="append", default=[], help="pattern (relativo a project-root) da escludere (prefisso). Puoi ripetere.")
    return p.parse_args()

def main():
    args = parse_args()
    try:
        generate_bundle(project_root=args.project_root,
                        output_file=args.output,
                        main_file=args.main,
                        force=args.force,
                        exclude=args.exclude,
                        verbose=args.verbose)
    except SystemExit as ex:
        print(str(ex), file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
