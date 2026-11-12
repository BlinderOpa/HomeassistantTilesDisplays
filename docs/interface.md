# Interface: Home Assistant ↔ displays (v1.15)

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
weather-hail weather-lightning weather-lightning-rainy weather-windy alarm alarm-off
clock-outline timer-outline fan battery-charging progress-clock school`

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
(and the brightness or night mode).

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

### 4.7 Action `set_calendar` (7", optional)

Optional week calendar as a second page of the wall display. Device side: package
`esphome/wall-display-calendar.yaml` (included in addition to `wall-display.yaml`);
HA side: package `wall_calendar.yaml`. Without the HA package the page stays off.

**Columns come from labels:** every label named `Kalender <name>` (or `Calendar <name>`) that is
given to at least one `calendar.*` entity is one column with the header `<name>`; all calendars
with that label share the column. Order alphabetical, `Alle`/`All`/`Familie`/`Family` last, max. 6.
No such label → page off. Works with any calendar integration (Google, CalDAV, Remote Calendar …).

```yaml
api:
  actions:
    - action: set_calendar
      variables:
        cal: string   # JSON, see below; "cols": [] = page off
```

```json
{"cols": [{"name": "Mama", "color": "#4FC3F7"}, {"name": "Alle", "color": "#A1887F"}],
 "days": [{"label": "Mi\n04.11.", "today": true,  "weekend": false, "cells": ["19:30 Elternabend", ""]},
          {"label": "Do\n05.11.", "today": false, "weekend": false, "cells": ["", "Feiertag"]}]}
```

| field | meaning |
|---|---|
| `cols` | max. 6 columns (one label each), `name` max. 14 chars, `color` `#RRGGBB` (fixed palette by position) |
| `days` | 7 rows from today; `label` = weekday + date (2 lines), `today` / `weekend` only change the row background |
| `cells` | one string per column, max. 3 lines separated by `\n` (HA already shortens and adds "+n weitere") |

The device only draws the grid (day column 64 px, header 34 px, rows 63 px) and clips text;
all sorting, shortening and colours come from HA. Navigation: swipe left on the base view →
calendar; swipe right or 60 s → back. HA resends on change of `sensor.wall_calendar` and on
`esphome.display_ready`.

The same package provides the tile `sensor.tile_calendar` (next event today, after 17:00 also
tomorrow; prio 28, icon `calendar`) for the small tiles in the base view.

### 4.8 Night mode and display sleep (7", C6, S3)

The backlight of the 7" can only be switched on/off (no PWM), so dimming at night does not help much.
Instead the device offers:

| entity | meaning |
|---|---|
| switch `Display Nachtmodus` | on = backlight off; a tap wakes the display |
| number `Display Wachzeit` | seconds the display stays on after a tap (5–600, default 30); every further touch restarts it |
| switch `Display Hintergrundbeleuchtung` | master switch: off = always dark (a tap switches it on permanently) |

While the backlight is off, LVGL is paused, so the waking tap never triggers a tile or button.
Also on in night mode: a tile with `status: alarm` (until it is gone), and `show_answer` /
`show_question` (for the wake time). When it goes dark, the 4×3 tile view is closed.
HA switches the night mode via the blueprint `display_brightness.yaml` (input `night_mode_entity`).

**C6:** same entities `Display Nachtmodus` and `Display Wachzeit` (5–600 s, default 30). The C6 backlight stays an
ordinary dimmable light entity (`Display Hintergrundbeleuchtung`): its brightness is set there, and
sleep or night mode only switch it off and on again, so the chosen brightness is kept. LVGL is not
paused, so the display simply goes off after the wake time. The wake events are touch (that touch
triggers nothing), the BOOT button, `show_answer`, `show_question` and a new tile with `status: alarm`;
while the assistant, an answer or a question is active the display stays on. By day the number
`Display-Timeout` (0 = never) switches the C6 off after that many idle seconds; at night the wake time
applies instead. For the C6 add a second instance of the blueprint with `brightness_entity` empty,
`node_name: voice-satellite-c6` and `night_mode_entity` = its `Display Nachtmodus` switch.

**S3:** works like the C6, without touch. Entities: number `Display-Timeout` (0 = never, default 30 s),
switch `Display Nachtmodus`, number `Display Wachzeit` (default 30 s); brightness stays on the light
`Display Helligkeit`. Wake events: wake word / start of listening, spoken answer, `show_answer`
(already when it arrives during speech), `show_question`, any of the three buttons and OTA. While the
assistant, an answer, a question or an update is active the display stays on, then 5 s more. After the
spoken answer the timeout starts again, so the sentence stays readable. For night mode add an instance
of the blueprint with `brightness_entity` empty, `node_name: voice-satellite-s3` and its
`Display Nachtmodus` switch.

### 4.9 Follow-up listening (C6)

By default a satellite listens for exactly one command. A voice automation can ask for one more:
`script.display_answer` has the optional field `listen_again` (default `false`). If it is `true`,
HA calls the device's API action `listen_again` (no variables) after the answer. The C6 then waits
until the spoken answer is over, pauses 1.2 s and listens again; silence ends the session quietly,
a recognised command allows the next follow-up. Devices without the action ignore it. The switch
`Folgebefehle` on the C6 (default on) can turn this off. Typical use: "Rollo hoch", then "Rollo stop".

## 5. What each device implements

| | S3 | C6 | 7" |
|---|---|---|---|
| `show_answer` | ✅ | ✅ | ✅ popup |
| `show_question` / `cancel_question` | ✅ buttons | ✅ | ✅ |
| `set_tiles` | – | ✅ swipe, no icon | ✅ |
| event `display_tap` | – | ✅ | ✅ |
| display sleep (number "Display-Timeout", 0 = never) | ✅ wakes on wake word, answer, question, button | ✅ wakes on touch, button, answer, question, new alarm tile | – |
| follow-up commands (switch "Folgebefehle") | – | ✅ keeps listening after an answer | – |
| event `display_ready` | optional | optional | ✅ |
| weather-station base view | – | – | ✅ |
| `set_background` | – | – | ✅ |
| night mode (switch "Display Nachtmodus", number "Display Wachzeit") | ✅ | ✅ | ✅ |
| `set_calendar` | – | – | optional (calendar package) |

## Change rules

New fields only as optional fields with a default (old devices ignore unknown JSON fields).
New icons go into 1.2 first, then into the devices. Incompatible changes bump the major version.

### Changelog
- v1.15: 7" without brightness: number `Display Helligkeit` and the dimming overlay removed (the backlight is on/off only; use the night mode, 4.8). Display `update_interval: never` (LVGL redraws itself), `min_version` 2026.9.0. HA: identify the 7" in `display_answer` by another entity (e.g. `number.<node>_display_wachzeit`); `display_brightness` without `brightness_entity`. Only the 7" firmware changes.
- v1.14: icons `clock-outline`, `timer-outline`, `fan` (voice blueprints time/date, timer, ventilation) on all devices; S3 and C6 also get `window-shutter`, `window-shutter-open`, `phone-missed`, `printer-3d`, `printer-3d-nozzle-alert` (voice answers); the 7" also gets `alarm`, `alarm-off`, `battery-charging`, `progress-clock`, `school` (tile icons). Firmware of all three devices changes (new glyphs only).
- v1.13: icons `alarm` and `alarm-off` (1.2) for the voice blueprint "alarm clock"; only S3 and C6 firmware change (the 7" has no voice).
- v1.12: display sleep and night mode for the S3 (4.8): number `Display-Timeout`, switch `Display Nachtmodus`, number `Display Wachzeit`; the backlight goes on briefly for every response. Only the S3 firmware changes.
- v1.11: follow-up listening (4.9): optional field `listen_again` of `display_answer` and C6 action `listen_again`. The C6 no longer listens again after every answer by itself (the earlier, unreleased "continuous" behaviour), only when HA asks.
- v1.10: night mode for the C6 (4.8): switch `Display Nachtmodus` and number `Display Wachzeit` like the 7". Blueprint `display_brightness`: `brightness_entity` is optional now. Only the C6 firmware changes.
- v1.9: 7" night mode (4.8): backlight off at night, tap wakes it for "Display Wachzeit"; alarm tiles and popups wake it too. Blueprint `display_brightness` switches it (optional input). Only the 7" firmware changes.
- v1.8: optional action `set_calendar` (4.7) and tile `sensor.tile_calendar`; columns via labels `Kalender <name>`. Existing devices unchanged.
