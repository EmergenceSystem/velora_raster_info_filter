# velora_raster_info_filter

An [Emergence](https://github.com/EmergenceSystem) filter that turns a text
query into **raster metadata** (size, bands, CRS, driver), computed by a
[velora](https://github.com/roquess/velora) node.

It is a thin adapter: it advertises a raster metadata capability vector on
the em_pop gossip mesh and, on `POST /agent/query`, forwards the query to
velora with intent `info`. velora does the real work — classify the query,
resolve the raster source, and inspect it via GDAL — and returns an info
card, which this filter relays.


<!-- emergence-context -->
Part of **[EmergenceSystem](https://github.com/EmergenceSystem)** — a distributed
discovery network of small, single-source agents. This filter joins the em_pop gossip
mesh and answers `POST /agent/query`; Emquest fans each query out to many filters in
parallel and aggregates the results.

## Contract

```
POST /agent/query
{"query": "chernobyl.tif"}        -> {"results": [{"type":"info","id":...,
                                                   "size":[W,H],
                                                   "bands":N,
                                                   "crs":"EPSG:4326",
                                                   "driver":"GTiff"}]}
```

A raster URL works directly (`{"query":"https://host/scene.tif"}`); a place
name requires velora to have a geocoder and STAC configured. If velora is
unreachable the filter returns `{"results": []}`.

## Configuration (`config/sys.config`)

| key | default | meaning |
|-----|---------|---------|
| `pop_port`   | 9214 | em_pop gossip port |
| `query_port` | 9215 | Cowboy HTTP query port |
| `pop_seeds`  | `[{"localhost",9100}]` | em_pop seed peers |
| `velora_url` | `http://127.0.0.1:8080/agent/query` | velora endpoint |

## Build & test

```
rebar3 compile
rebar3 ct
```

Apache-2.0.
