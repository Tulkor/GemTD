#!/usr/bin/env bash
# Grafiktreiber für Bilder aus dem Container (screenshot.sh, fx/vorschau.sh, modelle/vorschau.sh).
# Das Spiel läuft mit Vulkan (Forward+); im Container ohne Grafikkarte rendert Mesa lavapipe auf der CPU.
# Einbinden mit: source tools/render_treiber.sh  → danach "${RENDER_ARGS[@]}" an godot übergeben.
# RENDERER=opengl3 erzwingt den alten Compatibility-Renderer (nur zum Vergleich; weiche Effektkanten,
# Kontur und Spiegelung rechnen dann mit falschen Tiefenwerten).
if [ "${RENDERER:-vulkan}" = "opengl3" ]; then
  RENDER_ARGS=(--rendering-driver opengl3)
else
  ICD=/usr/share/vulkan/icd.d/lvp_icd.json
  if [ ! -f "$ICD" ]; then
    echo "Installiere Mesa-Vulkan (lavapipe) …" >&2
    { apt-get install -y -q mesa-vulkan-drivers libvulkan1 >/dev/null 2>&1 \
      || { apt-get update -q >/dev/null 2>&1 && apt-get install -y -q mesa-vulkan-drivers libvulkan1 >/dev/null 2>&1; }; } \
      || echo "Mesa-Vulkan ließ sich nicht installieren" >&2
  fi
  export VK_ICD_FILENAMES=$ICD
  RENDER_ARGS=(--rendering-driver vulkan --rendering-method forward_plus)
fi
