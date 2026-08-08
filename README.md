# Moosingin3space Tap

## Formulae

| Formula | Description | Platforms |
| --- | --- | --- |
| `gnome-foundry` | [GNOME Foundry](https://gitlab.gnome.org/GNOME/foundry) — command-line IDE tooling and library extracted from GNOME Builder. Installs the `foundry` CLI. | Linux |
| `spotifyd-linux` | [spotifyd](https://spotifyd.rs/) built with the PulseAudio backend enabled. | Linux |

## How do I install these formulae?

`brew install moosingin3space/tap/<formula>`

Or `brew tap moosingin3space/tap` and then `brew install <formula>`.

Or, in a `brew bundle` `Brewfile`:

```ruby
tap "moosingin3space/tap"
brew "<formula>"
```

Homebrew requires third-party taps to be trusted before it will load them. If
you hit `Refusing to load formula ... from untrusted tap`, run:

```bash
brew trust --tap moosingin3space/tap
```

## Documentation

`brew help`, `man brew` or check [Homebrew's documentation](https://docs.brew.sh).
