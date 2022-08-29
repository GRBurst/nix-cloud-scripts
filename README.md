# Nix Cloud Scripts

Nix Cloud Scripts serves as a central point to distribute simple scripts and tools that simplifies work with cloud environments.
Scripts are written to favor the use of `nix-shell`, since they provide the complete environment to run the script.
The repository structure categorizes scripts by their domain, e.g. `aws` or `terraform`.

You can find installation instructions for nix on the [official website](https://nixos.org/download.html#nix-install-linux).

To reduce the boilerplate, we add [script-cook](https://github.com/GRBurst/script-cook) as a submodule, so don't forget to add the `--recursive` flag when you clone the repo, e.g.

```bash
git clone --recursive https://github.com/GRBurst/nix-cloud-scripts.git
```


## Run a script

If you have `nix` and `nix-shell` installed on your system, you can run the scripts directly using:

```
./script-cook/template.sh
```

If you don’t have `nix-shell` on your system, you have to take care of the needed dependencies and run it explicitly using bash, e.g.

```
bash ./script-cook/template.sh
```

## Adding a script

Please use the templates `template.sh` and `template-aws.sh`.
It contains a description as well.
You can open a pull request at any time and I am happy to help in a draft PR 😉
