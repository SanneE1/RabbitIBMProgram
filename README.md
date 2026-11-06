# Rabbit population model

Spatially explicit, stochastic population model of the European rabbit in Doñana, written in Free
Pascal. It is a console program: R (the calibration and forecasting workflows) starts it with a
rates file and `--name=value` settings, and reads the files it writes. All settings are described in
[model_settings.md](model_settings.md).

Ready-built executables are in `programs/`:

| File | Platform |
|---|---|
| `Rabbit_x86_64-win64.exe` | Windows, 64-bit |
| `Rabbit_x86_64-linux` | Linux, x86_64 (also used in the Docker containers) |
| `Rabbit_x86_64-darwin` | macOS, Intel |
| `Rabbit_aarch64-darwin` | macOS, Apple silicon |

`Rabbit_x86_64-linux --version` (or any other build) prints the settings interface; the R code
checks that it is `settings_interface 2`.

## Building

The program only needs the Free Pascal compiler (FPC 3.2 or later) and its standard units; it uses
no GUI library. Errors are written to standard error, and the program exits with code 1.

Run the commands from this folder. They write the executable to `programs/` and the compiled units
to `lib/<cpu>-<os>/`. After a code change, rebuild and commit the executables for every platform,
so that R and the executables stay in step.

### Windows

With Lazarus installed (it includes FPC), use the project's `Release` build mode:

```
C:/lazarus/lazbuild.exe --build-mode=Release Rabbit_calibration.lpi
```

or open `Rabbit_calibration.lpi` in Lazarus, choose the `Release` build mode and build.

### Linux

With FPC installed (Debian/Ubuntu: `apt install fp-compiler fp-units-base fp-units-rtl fp-units-fcl libc6-dev`):

```
fpc -MObjFPC -Scghi -O3 -XX -CX -Xs -Fulynx -Furabbit -FUlib/x86_64-linux -FEprograms -oRabbit_x86_64-linux Rabbit_calibration.lpr
```

Without a Linux machine, build in a Docker container (from this folder, e.g. on Windows in Git Bash
or PowerShell):

```
docker run --rm -v "$PWD:/src" -w /src debian:bookworm-slim bash -c \
  "apt-get update && apt-get install -y --no-install-recommends fp-compiler fp-units-base fp-units-rtl fp-units-fcl libc6-dev \
   && fpc -MObjFPC -Scghi -O3 -XX -CX -Xs -Fulynx -Furabbit -FUlib/x86_64-linux -FEprograms -oRabbit_x86_64-linux Rabbit_calibration.lpr"
```

(In Git Bash, prefix the command with `MSYS_NO_PATHCONV=1` so `/src` is not turned into a Windows
path.)

### macOS

With FPC installed (e.g. `brew install fpc`), on an Apple silicon Mac:

```
fpc -MObjFPC -Scghi -O3 -XX -CX -Xs -Fulynx -Furabbit -FUlib/aarch64-darwin -FEprograms -oRabbit_aarch64-darwin Rabbit_calibration.lpr
```

and on an Intel Mac:

```
fpc -MObjFPC -Scghi -O3 -XX -CX -Xs -Fulynx -Furabbit -FUlib/x86_64-darwin -FEprograms -oRabbit_x86_64-darwin Rabbit_calibration.lpr
```

Lazarus users can use the `Release_MacOS_aarch64` and `Release_MacOS_intel` build modes instead.

### Checking a build

```
programs/Rabbit_x86_64-linux --version
```

prints `Rabbit population model` and `settings_interface 2`. Started without `--rates_file`, the
program prints `Error: --rates_file is required` and exits with code 1.
