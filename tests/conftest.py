#!/usr/bin/env python3

import pytest
import sys
import os
import json
import subprocess
from pathlib import Path
from typing import Type, Iterator, List, Union, Dict, Any, cast
import shutil
import tempfile
from contextlib import contextmanager
from dataclasses import dataclass


TEST_ROOT = Path(__file__).parent.resolve()
sys.path.append(str(TEST_ROOT.parent))


@dataclass
class Nixpkgs:
    path: Path
    remote: Path


def run(cmd: List[Union[str, Path]]) -> None:
    subprocess.run(cmd, check=True)


def real_nixpkgs() -> str:
    output = subprocess.run(
        ["nix-instantiate", "--find-file", "nixpkgs"],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    ).stdout.strip()
    return output


def setup_nixpkgs(target: Path) -> Path:
    shutil.copytree(
        Helpers.root().joinpath("assets/nixpkgs"),
        target,
        dirs_exist_ok=True,
    )

    default_nix = target.joinpath("default.nix")

    with open(default_nix) as r:
        text = r.read().replace("@NIXPKGS@", real_nixpkgs())

    with open(default_nix, "w") as w:
        w.write(text)

    return target


def setup_git(path: Path) -> Nixpkgs:
    os.chdir(path)
    os.environ["GIT_AUTHOR_NAME"] = "nixpkgs-review"
    os.environ["GIT_AUTHOR_EMAIL"] = "nixpkgs-review@example.com"
    os.environ["GIT_COMMITTER_NAME"] = "nixpkgs-review"
    os.environ["GIT_COMMITTER_EMAIL"] = "nixpkgs-review@example.com"

    run(["git", "-C", path, "init", "-b", "master"])
    run(["git", "-C", path, "add", "."])
    run(["git", "-C", path, "commit", "-m", "first commit"])

    remote = path.joinpath("remote")
    run(["git", "-C", path, "init", "--bare", str(remote)])
    run(["git", "-C", path, "remote", "add", "origin", str(remote)])
    run(["git", "-C", path, "push", "origin", "HEAD"])
    return Nixpkgs(path=path, remote=remote)


class Helpers:
    @staticmethod
    def root() -> Path:
        return TEST_ROOT

    @staticmethod
    def load_report(review_dir: str) -> Dict[str, Any]:
        with open(os.path.join(review_dir, "report.json")) as f:
            return cast(Dict[str, Any], json.load(f))

    @staticmethod
    @contextmanager
    def nixpkgs() -> Iterator[Nixpkgs]:
        with tempfile.TemporaryDirectory() as tmpdirname:
            path = Path(tmpdirname)
            nixpkgs_path = path.joinpath("nixpkgs")
            os.environ["XDG_CACHE_HOME"] = str(path.joinpath("cache"))
            yield setup_git(setup_nixpkgs(nixpkgs_path))


# pytest.fixture is untyped
@pytest.fixture  # type: ignore
def helpers() -> Type[Helpers]:
    return Helpers
