# HA Wall Tiles

Situational **tiles** for ESPHome touch displays and voice satellites, driven entirely by
Home Assistant: a 7" wall display that replaces a weather station, plus small voice satellites
that show answers and let you swipe through the same tiles.

Home Assistant decides *what* is shown; the devices only decide *how*. Adding a tile never
requires reflashing a device.

> Display texts and voice sentences are **German**. Code, comments and docs are English
> (except the comments in the ESPHome files). Translating = editing the strings / blueprint inputs.

## How it is organised

**Logic lives in blueprints, your entities live in one file of your own.**
The repository contains no entity ids of a real home – you pass yours as blueprint inputs
(see [`examples/my_wall_tiles.yaml`](examples/my_wall_tiles.yaml)). Updating = replacing the
blueprint files; your own file stays untouched.

```
blueprints/
  template/wall_tiles/        TILES (one entity per blueprint instance, YAML only)
    tile_socket               smart plug: on/off + power, tap toggles
    tile_binary_alarm         visible while a binary sensor is on (leak, door …)
    tile_device_fault         fault (red) / warning (orange) of a device + error texts
    tile_appliance            running appliance: time left + progress bar
    tile_appliance_done       "Wäsche fertig" – tap = unloaded
    tile_battery_charger      cell charger on a plug: "lädt · noch 3" / "voll"
    tile_3d_printer           Moonraker: progress or error mode
    tile_batteries            all battery sensors below a limit
    tile_room_humidity        all humidity sensors by area, hysteresis, tap = ventilation boost
    tile_room_cold            all temperature sensors by area
    tile_air_quality          all CO₂ / PM2.5 sensors
    tile_weather_warning      DWD warnings, icon by type
    tile_shutters_check       "Rollos runter?" / "Rollos hoch?" – tap runs the group script
    tile_pool                 pH / redox in season
    tile_pv_surplus           PV surplus with hysteresis
    tile_power                house consumption, biggest consumer, "nicht erfasst"
    tile_hot_water            DHW cold, time to heat up, blocking times
    tile_maintenance          collective hints: filter, toner, backup, repairs, offline …
    train_next + tile_train   Deutsche Bahn delay (helper sensor + tile)
  automation/wall_tiles/
    tile_tap_handler          tap on a tile → toggle / run action        (once)
    tiles_push                send tiles to one ESPHome display          (per display)
    display_brightness        day / evening / night brightness
    appliance_done_detect     sets the "done" flag of an appliance
    voice_ack_tile            "Müll ist draußen" = tap by voice
    voice_switch_tile         "E-Bike laden" / "E-Bike aus"
    voice_shutters_group      "Untere Rollos runter"
    voice_appliance · voice_charging_plug · voice_3d_printer · voice_waste
    voice_train · voice_weather · voice_energy
  script/wall_tiles/
    display_answer            → script.display_answer (required)
    shutters_group            open / close a group, one shutter only partially
    appliance_unloaded        clear the done flag (+ press "unloaded" button)
packages/                     only what needs fixed helpers or trigger-based templates
  wall_tiles/tiles_collector  (required) collects all sensor.tile_*
  wall_tiles/tile_waste       waste calendar (Waste Collection Schedule)
  wall_tiles/tile_calls       FRITZ!Box call monitor: incoming + missed calls (+ "Wer hat angerufen?")
  wall_tiles/tile_rain        rain within 2 h (hourly forecast)
  wall_tiles/tile_school      WebUntis cancelled lessons
  voice/voice_shutters        shutters per room by voice, stop, tile "Rollo fährt"
  weather_station             sensor.ws_* for the 7" base view
examples/my_wall_tiles.yaml   YOUR configuration: all blueprint calls in one package
esphome/                      device firmware (ESPHome + LVGL) + examples/ for your device files
docs/interface.md             the contract between HA and the devices
tools/check_private.sh        scan for private data before you push
```

## Requirements

- Home Assistant 2025.x or newer (template blueprints, `conversation` triggers, labels)
- Packages enabled in `configuration.yaml`:
  ```yaml
  homeassistant:
    packages: !include_dir_named packages
  ```
- ESPHome devices with "Allow the device to perform Home Assistant actions" enabled.
- Voice: Assist with Speech-to-Phrase or any STT. Restart Speech-to-Phrase after adding sentences.

## Installation

1. Copy `blueprints/` into `config/blueprints/` (or import single files by URL).
2. Copy `packages/wall_tiles/tiles_collector.yaml` and the packages you want into `config/packages/`
   and edit their `── ADAPT ──` block.
3. Copy `examples/my_wall_tiles.yaml` to `config/packages/`, delete what you don't have and
   enter your entity ids. (Automations and scripts can also be created in the UI from the blueprints.)
4. *Developer tools → YAML → reload all*.
5. Give every `sensor.tile_*` the label **Display** (Settings → Entities → Labels).
   `input_boolean.wall_tiles_debug` shows all tiles, also hidden/unlabelled ones, for 15 min.

### ESPHome devices

Your device file only contains name and key; the rest is pulled from this repository:

```yaml
substitutions:
  node_name: my-wall-display        # keep your existing name → entity ids stay
  friendly_name: "My Wall Display"
  api_key: !secret wall_display_api_key
packages:
  wall_tiles:
    url: https://github.com/BlinderOpa/HomeassistantTilesDisplays
    ref: main
    files: [esphome/wall-display.yaml]
    refresh: 1d
```

See `esphome/examples/` and `esphome/secrets.example.yaml`.

## Writing your own tile

```yaml
template:
  - sensor:
      - name: "Tile Garage"          # → sensor.tile_garage, tile id "garage"
        unique_id: tile_garage
        icon: mdi:garage-open
        state: "{{ 'warn' if is_state('cover.garage', 'open') and now().hour >= 21 else 'hidden' }}"
        attributes:
          prio: 24
          title: "Garage offen"
          value: "seit {{ as_local(states.cover.garage.last_changed).strftime('%H:%M') }}"
          tap: "ack"
          action: "script.close_garage"
```

States: `alarm` `warn` `ok` `info` `on` `off` or `hidden`. All fields: [docs/interface.md](docs/interface.md).

## Before you publish your fork

Put your private words (names, town, serials) into `tools/private_terms.txt` (git-ignored) and run
`tools/check_private.sh`. Keep credentials in `esphome/secrets.yaml` (git-ignored).

## License

MIT – see [LICENSE](LICENSE).
