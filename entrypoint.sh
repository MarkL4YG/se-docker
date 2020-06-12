#!/bin/bash
# Licenced under the MIT from Johan Bregell, and adapted.
# Find the original here:
# https://github.com/bregell/docker_space_engineers_server/blob/38c7d3d8f2b6bdbfcfb45f84b3b2df1c128eb99f/entrypoint.sh

set -eo pipefail

mkdir -p "${SE_WORKING_DIR}"
mkdir -p "${SE_CONFIG_DIR}"/{Saves,Mods,Updater}
if [[ -d "${SE_WORKING_DIR}"/"${WORLD_NAME}" ]]; then
  cp -r --reflink=auto --no-preserve=ownership \
    "${SE_WORKING_DIR}"/"${WORLD_NAME}" "${SE_CONFIG_DIR}"/Saves/
fi

if [[ ! -s "${SE_CONFIG_DIR}"/SpaceEngineers-Dedicated.cfg ]]; then
  # Upsert a default configuration with sane defaults for this containerized environment.
  : ${WORLD_SAVE_WINE_PATH:="C:\\\users\\\container\\\AppData\\\Roaming\\\SpaceEngineersDedicated\\\Saves\\"}
  : ${PREMADE_WINE_PATH:="C:\\\SpaceEngineersDedicatedServer\\\Content\\\CustomWorlds\\\Star System"}

  declare -A defaults=(
    [SteamPort]="${STEAM_PORT}"
    [ServerPort]="${SERVER_PORT}"
    [RemoteApiPort]="${SERVER_API_PORT}"
    [RemoteSecurityKey]="${REMOTE_SECURITY_KEY}"
    [ServerName]="${SERVER_NAME}"
    [WorldName]="${WORLD_NAME}"
    [LoadWorld]="${WORLD_SAVE_WINE_PATH}\\${WORLD_NAME}"
    [PremadeCheckpointPath]="${PREMADE_WINE_PATH}"
  )

  modifications=()
  for tag in "${!defaults[@]}"; do
    modifications+=("-e" "s#<${tag}>.*</${tag}>#<${tag}>${defaults[$tag]}</${tag}>#g")
  done

  <"/etc/default/SpaceEngineers-Dedicated.cfg" sed "${modifications[@]}" >"${SE_CONFIG_DIR}"/SpaceEngineers-Dedicated.cfg
fi

steamcmd \
  +login anonymous \
  +force_install_dir "${SE_WORKING_DIR}" \
  +app_update 298740 \
  +quit

# Allow for a different IP in case the operator runs this image with "--net=host"
# on a multi-homed server, or multiple instances of this game.
: ${SERVER_IP:="0.0.0.0"}

# Change the working directory to the directory containing the steam binaries,
# otherwise the game server won't start.
cd "${SE_WORKING_DIR}/DedicatedServer64"

if [[ -z "$STARTUP" ]]; then
    STARTUP="wine64 SpaceEngineersDedicated.exe -noconsole -ignorelastsession -ip \"${SERVER_IP}\" -path \"$(winepath -w "${SE_CONFIG_DIR}")\""
fi

# Replace Startup Variables
MODIFIED_STARTUP=$(eval echo $(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g'))
echo ":$(pwd)$ ${MODIFIED_STARTUP}"

# Run the Server
eval ${MODIFIED_STARTUP}
