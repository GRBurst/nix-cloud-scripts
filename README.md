# Nix Cloud Scripts

Nix Cloud Scripts serves as a central point to distribute simple scripts and tools that simplifies work with cloud environments.
Scripts are written to favor the use of `nix-shell`, since they provide the complete environment to run the script.
The repository structure categorizes scripts by their domain, e.g. `aws` or `terraform`.

You can find installation instructions for nix on the [official website](https://nixos.org/download.html#nix-install-linux).

To reduce the boilerplate, we depend on [script-cook](https://github.com/GRBurst/script-cook).
For compatibility with plain bash (if you **don't** use nix-shell) we add it as a submodule, so don't forget to add the `--recursive` flag when you clone the repo, e.g.
However, this is not necessary if you are utilizing nix.

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

Don't forget to clone recursively in that case.


## Contribute

To get started, you can just copy one of the templates like `template.sh` or `aws/template.sh` and change the following:

1. Options / parameters your script.
2. Usage / help message with examples.
3. Body of the `run()` function.

It is wise to keep the nix-shell pure, e.g. add / keep the `nix-shell --pure` parameter in the shebang.
This guarantees that you don't forget to add the necessary dependencies to run the script.
The templates contain some descriptions as well.

However, if your script requires a tool that needs to interact with the environment like `aws-vault`, which allows for requesting a token via sso of your **system's default browser**, you want to remove it before releasing it to the public.

You can open a pull request at any time and I am happy to help in a draft PR 😉
