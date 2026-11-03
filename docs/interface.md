# Interface: Home Assistant ↔ displays (v1.7)

Applies to every device that shows tiles or answers. Reference devices:

| Device | Display | Role |
|---|---|---|
| Voice satellite S3 | Waveshare ESP32-S3-LCD-0.85, ~128×128 | answers, yes/no via buttons |
| Voice satellite C6 | Waveshare ESP32-C6-Touch-LCD-1.83, ~240×284 | answers, yes/no via touch, swipe through tiles |
| Wall display 7" | Waveshare ESP32-S3-Touch-LCD-7, 800×480 | weather-station base view, tiles, popups |

**Principle:** Home Assistant decides *what* is shown (content, relevance, priority).
Each device decides *how* (layout for its size). Logic lives only in HA; devices stay "dumb".

> HA action names follow the ESPHome node name: `esphome.<node>_<action>` (dashes → underscores).
> Every ESPHome device needs "Allow the device to perform Home Assistant actions" enabled for events.

## 1. Common terms

### 1.1 Status (sets the colour)

| status | meaning | colour (suggestion) |
|---|---|---|
| `alarm` | act now | red `#E53935` |
| `warn` | act soon | orange `#FB8C00` |
| `ok` | fine / done | green `#43A047` |
| `info` | neutral | blue `#1E88E5` |
| `on` | switch on | yellow `#FDD835` |
| `off` | switch off | grey `#616161` |

Unknown status → like `info`.

### 1.2 Icons

MDI names **without** `mdi:`. Each device only embeds the glyphs it needs; unknown → `information`.

`check close alert information help trash-can trash-can-outline train washing-machine washing-machine-alert
thermometer thermometer-alert thermometer-high water-alert water-percent-alert water-thermometer battery-alert
power-plug pool door-open molecule-co2 solar-power printer printer-3d printer-3d-nozzle-alert cart wifi
bicycle-electric pump calendar lightbulb fire flash wrench phone-ring phone-missed heat-pump fan-alert
window-shutter window-shutter-open snowflake-alert weather-sunny weather-night weather-partly-cloudy
weather-cloudy weather-rainy weather-pouring weather-snowy weather-snowy-heavy weather-snowy-rainy weather-fog
weather-hail weather-lightning weather-lightning-rainy weather-windy`

### 1.3 Text lengths

HA truncates before sending: `title` 16, `value` 20, `detail` 40 characters.

## 2. Action `show_answer` (all devices)

```yaml
api:
  actions:
    - action: show_answer
      variables:
        title: string
        value: string
        detail: string    # "" if empty
        status: string    # 1.1
        icon: string      # 1.2
        duration: int     # seconds, 0 = device default (8 s)
```

Satellites: if `show_answer` arrives while speaking, show it after the speech ends.
HA side: always through `script.display_answer` (blueprint `display_answer.yaml`), field `target` = device id / `wall` / `all`.

## 3. Yes/no: `show_question`, `cancel_question`, event `esphome.display_question_answer`

```yaml
api:
  actions:
    - action: show_question
      variables: {request_id: string, question: string, icon: string, timeout: int}
    - action: cancel_question
      variables: {request_id: string}
```

The device sends exactly one event:

```yaml
homeassistant.event:
  event: esphome.display_question_answer
  data: {device: <node>, request_id: <as received>, answer: yes}   # yes | no | timeout | cancelled
```

## 4. Tiles

### 4.1 A tile in HA

A tile is **one template sensor** whose entity id starts with `sensor.tile_` and that has the
**label `Display`** (labels can only be set in the UI, so a `unique_id` is required).
The tile `id` is the part after `sensor.tile_`. HA turns umlauts into a/o/u in entity ids.

- **state** = status from 1.1 or `hidden`
- **icon** = the normal entity icon (may be a template). Do **not** add an attribute `icon`.
- **attributes**

| attribute | type | required | meaning |
|---|---|---|---|
| `prio` | int | yes | sort order: 0–9 alarm, 10–19 warning, 20–49 situational, 50+ fixed switches |
| `title` | string | yes | |
| `value` | string | no | |
| `detail` | string | no | |
| `progress` | int | no | 0–100 progress bar, -1 = none |
| `tap` | string | no | `none` (default), `toggle`, `ack`, `info` |
| `mini_icon` | string | no | 7" only: `auto`, `show`, `hide` |
| `entity` | string | no | HA-internal: entity toggled on `tap: toggle` (not sent) |
| `action` | string | no | HA-internal: script/scene/boolean turned on for `tap: ack` (not sent) |

Round fast-changing values (power) so not every small change triggers a new send.

### 4.2 Action `set_tiles`

`sensor.wall_tiles` (package `tiles_collector.yaml`) builds the sorted list (max. 12) in its
attribute `tiles`; the blueprint `tiles_push.yaml` sends it as JSON on every change.

```yaml
api:
  actions:
    - action: set_tiles
      variables:
        tiles: string   # JSON array, max. 12, sorted by prio
```

```json
[{"id":"water","status":"alarm","icon":"water-alert","title":"Wasser!","value":"Lüftung","detail":"Wassermelder hat ausgelöst","prio":0,"tap":"none","progress":-1},
 {"id":"washer","status":"info","icon":"washing-machine","title":"Wäsche läuft","value":"noch 42 min","detail":"Baumwolle 40","prio":30,"tap":"none","progress":61}]
```

The device is stateless: every `set_tiles` replaces all tiles. Missing optional fields → defaults.
Compact mode (small devices) only sends `id, tap, status, title, value, detail`.

### 4.3 Event `esphome.display_tap`

```yaml
homeassistant.event:
  event: esphome.display_tap
  data: {device: <node>, id: <tile id>, tap: toggle}
```

HA decides what happens (blueprint `tile_tap_handler.yaml`). Voice commands send the same event with `device: voice`.

### 4.4 Event `esphome.display_ready`

Sent by the device on `api: on_client_connected`; HA answers with an immediate `set_tiles`
(and sets the brightness).

### 4.5 Weather-station base view (7")

The display reads only these entities (package `weather_station.yaml`):

| entity | content |
|---|---|
| `sensor.ws_outdoor_temp`, `sensor.ws_outdoor_max`, `sensor.ws_outdoor_min` | °C |
| `sensor.ws_outdoor_humidity`, `sensor.ws_indoor_humidity` | % |
| `sensor.ws_indoor_temp` | °C |
| `sensor.ws_comfort` | `gut` · `trocken` · `feucht` · `kalt` · `warm` · `unbekannt` |
| `sensor.ws_forecast` | state = HA condition; attributes `symbol`, `text`, `temp_max`, `temp_min`, `rain` |
| `sensor.ws_sunrise`, `sensor.ws_sunset` | "HH:MM" |

Layout (800×480): outdoor top left · forecast top centre · indoor top right · big clock in the middle ·
bottom: sunrise/sunset, or up to 4 small tiles (+n) that open the 4×3 tile view.
A tile with `status: alarm` additionally shows a big red banner.

### 4.6 Action `set_background` (7")

```yaml
api:
  actions:
    - action: set_background
      variables:
        url: string   # baseline JPEG, 800×480, already darkened; "" = no background
```

The device downloads the image (`online_image`) and shows it unchanged behind the base view;
panels are slightly transparent. HA picks and prepares the photo: blueprint
`weather_background.yaml` + package `weather_background.yaml` (random file from
`<root>/<weather condition>/`, else `<root>/default/`, scaled/cropped and darkened with ffmpeg,
served from `/local/wall_display/<node>.jpg` with a cache-busting `?v=`).

## 5. What each device implements

| | S3 | C6 | 7" |
|---|---|---|---|
| `show_answer` | ✅ | ✅ | ✅ popup |
| `show_question` / `cancel_question` | ✅ buttons | ✅ | ✅ |
| `set_tiles` | – | ✅ swipe, no icon | ✅ |
| event `display_tap` | – | ✅ | ✅ |
| event `display_ready` | optional | optional | ✅ |
| weather-station base view | – | – | ✅ |
| `set_background` | – | – | ✅ |

## Change rules

New fields only as optional fields with a default (old devices ignore unknown JSON fields).
New icons go into 1.2 first, then into the devices. Incompatible changes bump the major version.
