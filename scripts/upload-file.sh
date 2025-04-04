#!/bin/bash

# From https://github.com/vitorgalvao/tiny-scripts/blob/1ae0927af0c4d31306257a483ffd1288de706d19/upload-file

readonly program="$(basename "${0}")"
readonly hosts=(
  '0x0.st'
  'litterbox.catbox.moe'
  'transfer.sh'
  'transfer.archivete.am'
  'pixeldrain.com'
  'free.keep.sh'
  'oshi.at'
  'bayfiles.com'
  'anonfile.com'
  'rapidshare.nu'
  'forumfiles.com'
)
readonly default_host="${hosts[1]}"

# Create and cleanup temporary directories
readonly tmp_dir="$(mktemp -d)"
readonly tmp_zip_dir="$(mktemp -d)/archive"
mkdir "${tmp_zip_dir}"
trap 'rm -rf "${tmp_dir}" "${tmp_zip_dir}"' EXIT

function ascii_basename {
  basename "${1}" | sed -e 's/[^a-zA-Z0-9._-]/-/g'
}

function is_string_in_array {
  local -r string="${1}"

  for value in "${@:2}"; do
    [[ "${string}" == "${value}" ]] && return 0
  done

  return 1
}

function kopimi_parse {
  local -r json="$(< /dev/stdin)"

  osascript -l JavaScript -e 'function run(argv) {
    const data = JSON.parse(argv[0])
    if (!data["status"]) { return "There was an error uploading" }
    return data["data"]["file"]["url"]["full"]
  }' "${json}"
}

function pixeldrain_parse {
  local -r json="$(< /dev/stdin)"

  osascript -l JavaScript -e 'function run(argv) {
    const data = JSON.parse(argv[0])
    if (data["success"] === false) { return data["message"] }
    return "https://pixeldrain.com/u/" + data["id"]
  }' "${json}"
}

function usage {
  echo "
    Upload files and directories to a file hosting service.
    If multiple files or a directory are given, they will be zipped beforehand.
    To set a host as the default, export UPLOAD_FILE_TO in your shell.

    Valid hosts:
      $(printf '\n      %s' "${hosts[@]}")

    Usage:
      ${program} [options] <path...>

    Options:
      -u, --upload-host <host>   File host to upload to. Defaults to ${default_host}.
      -h, --help                 Show this help.
  " | sed -E 's/^ {4}//'
}

# Options
args=()
while [[ "${1}" ]]; do
  case "${1}" in
    -h | --help)
      usage
      exit 0
      ;;
    -u | --upload-host)
      UPLOAD_FILE_TO="${2}"
      shift
      ;;
    --)
      shift
      args+=("${@}")
      break
      ;;
    -*)
      echo "Unrecognised option: ${1}"
      exit 1
      ;;
    *)
      args+=("${1}")
      ;;
  esac
  shift
done
set -- "${args[@]}"

if [[ "${#}" -lt 1 ]]; then
  usage
  exit 1
fi

# Abort if any of the paths is invalid
for path in "${@}"; do
  if [[ ! -e "${path}" ]]; then
    echo "${path} does not exist." >&2
    exit 1
  fi
done

# If acting on multiple files or a software bundle, first copy them to a directory
if [[ "${#}" -gt 1 || -d "${1}/Contents" ]]; then
  cp -r "${@}" "${tmp_zip_dir}"
  readonly given_file="${tmp_zip_dir}"
else
  readonly given_file="${1}"
fi

# Make zip if acting on a directory
if [[ -d "${given_file}" ]]; then
  readonly dir_name="$(ascii_basename "${given_file}")"
  readonly zip_file="${tmp_dir}/${dir_name}.zip"
  DITTONORSRC=1 ditto -ck "${given_file}" "${zip_file}"
  readonly file_path="${zip_file}"
else
  readonly file_path="${given_file}"
fi

# Escape quotes, so we can quote curl's "--form"
# to allow for filenames with commas and semicolons
readonly escaped_file_path="${file_path//\"/\\\"}"

# Upload
if [[ -n "${UPLOAD_FILE_TO}" ]]; then
  if is_string_in_array "${UPLOAD_FILE_TO}" "${hosts[@]}"; then
    readonly upload_host="${UPLOAD_FILE_TO}"
  else
    echo "Invalid upload host: ${UPLOAD_FILE_TO}" >&2
    exit 1
  fi
else
  readonly upload_host="${default_host}"
fi

if [[ "${upload_host}" == '0x0.st' ]]; then
  readonly url="$(curl --globoff --progress-bar --form "file=@\"${escaped_file_path}\"" "https://${upload_host}")"
elif [[ "${upload_host}" == 'litterbox.catbox.moe' ]]; then
  readonly url="$(curl --globoff --progress-bar --form 'reqtype=fileupload' --form 'time=72h' --form "fileToUpload=@\"${escaped_file_path}\"" "https://${upload_host}/resources/internals/api.php")"
elif [[ "${upload_host}" == 'transfer.sh' ]]; then
  readonly url="$(curl --globoff --progress-bar --upload-file "${file_path}" "https://${upload_host}")"
elif [[ "${upload_host}" == 'transfer.archivete.am' ]]; then
  readonly url="$(curl --globoff --progress-bar --upload-file "${file_path}" "https://${upload_host}")"
elif [[ "${upload_host}" == 'pixeldrain.com' ]]; then
  readonly url="$(curl --globoff --progress-bar --upload-file "${file_path}" "https://${upload_host}/api/file/" | pixeldrain_parse)"
elif [[ "${upload_host}" == 'free.keep.sh' ]]; then
  readonly url="$(curl --globoff --progress-bar --upload-file "${file_path}" "https://${upload_host}")"
elif [[ "${upload_host}" == 'oshi.at' ]]; then
  readonly url="$(curl --globoff --progress-bar --upload-file "${file_path}" "https://${upload_host}" | grep ' \[Download\]' | sed 's/ \[Download\].*//')"
else
  readonly url="$(curl --globoff --progress-bar --form "file=@\"${escaped_file_path}\"" "https://api.${upload_host}/upload" | kopimi_parse)"
fi

echo -n "${url}" | pbcopy
echo "Copied to clipboard: ${url}"