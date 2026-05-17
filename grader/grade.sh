#!/usr/bin/env bash

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FIXTURE_DIR="${REPO_ROOT}/fixtures"
EXPECTED_DIR="${SCRIPT_DIR}/expected_outputs"
OUT_DIR="${REPO_ROOT}/out"
CLI_PATH="${REPO_ROOT}/cli.sh"

JQ=""
for candidate in jq /opt/homebrew/bin/jq /usr/local/bin/jq; do
	if command -v "${candidate}" >/dev/null 2>&1; then
		JQ="$(command -v "${candidate}")"
		break
	elif [ -x "${candidate}" ]; then
		JQ="${candidate}"
		break
	fi
done

if [ -z "${JQ}" ]; then
	echo "jq is required but not found. Install jq and try again." >&2
	exit 1
fi

if [ ! -d "${FIXTURE_DIR}" ]; then
	echo "Missing fixtures directory: ${FIXTURE_DIR}" >&2
	exit 1
fi

if [ ! -d "${EXPECTED_DIR}" ]; then
	echo "Missing expected_outputs directory: ${EXPECTED_DIR}" >&2
	exit 1
fi

if [ ! -f "${CLI_PATH}" ]; then
	echo "Missing cli.sh: ${CLI_PATH}" >&2
	exit 1
fi

cd "${REPO_ROOT}" || exit 1
mkdir -p "${OUT_DIR}"

TOTAL_CASES=0
PASSED_CASES=0

check_sorted_rejected_votes() {
	local output_path="$1"

	"${JQ}" -e '
		if has("rejected_votes") and .rejected_votes != null then
			(.rejected_votes | type == "array")
			and (
				(.rejected_votes | length <= 1)
				or ((.rejected_votes | sort_by([.address // "", .code // ""])) == .rejected_votes)
			)
		else
			true
		end
	' "${output_path}" >/dev/null 2>&1
}

check_sorted_warnings() {
	local output_path="$1"

	"${JQ}" -e '
		if has("warnings") and .warnings != null then
			(.warnings | type == "array")
			and (
				(.warnings | length <= 1)
				or ((.warnings | sort_by(.code)) == .warnings)
			)
		else
			true
		end
	' "${output_path}" >/dev/null 2>&1
}

compare_json_files() {
	local actual_path="$1"
	local expected_path="$2"

	local actual_norm
	local expected_norm

	actual_norm="$(${JQ} -cS '.' "${actual_path}")"
	expected_norm="$(${JQ} -cS '.' "${expected_path}")"

	[ "${actual_norm}" = "${expected_norm}" ]
}

shopt -s nullglob
fixture_files=("${FIXTURE_DIR}"/*.json)
shopt -u nullglob

if [ "${#fixture_files[@]}" -eq 0 ]; then
	echo "No fixtures found in ${FIXTURE_DIR}" >&2
	exit 1
fi

for fixture_path in "${fixture_files[@]}"; do
	fixture_name="$(basename "${fixture_path}")"
	fixture_stem="${fixture_name%.json}"
	output_path="${OUT_DIR}/${fixture_name}"
	expected_path="${EXPECTED_DIR}/${fixture_name}"
	stdout_path="${OUT_DIR}/.${fixture_stem}.stdout"
	stderr_path="${OUT_DIR}/.${fixture_stem}.stderr"

	TOTAL_CASES=$((TOTAL_CASES + 1))

	echo ""
	echo "=== ${fixture_name} ==="

	if [ ! -f "${expected_path}" ]; then
		echo "Missing expected output: ${expected_path}" >&2
		continue
	fi

	rm -f "${output_path}" "${stdout_path}" "${stderr_path}"

	cli_exit=0
	if bash "${CLI_PATH}" "fixtures/${fixture_name}" >"${stdout_path}" 2>"${stderr_path}"; then
		cli_exit=0
	else
		cli_exit=$?
	fi

	if [ "${cli_exit}" -ne 0 ]; then
		echo "FAIL: cli.sh exited ${cli_exit}"
		if [ -s "${stderr_path}" ]; then
			stderr_text="$(tr '\n' ' ' < "${stderr_path}" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
			echo "  stderr: ${stderr_text}"
		fi
		rm -f "${stdout_path}" "${stderr_path}"
		continue
	fi

	if [ ! -f "${output_path}" ]; then
		echo "FAIL: output file not created (${output_path})"
		rm -f "${stdout_path}" "${stderr_path}"
		continue
	fi

	if ! "${JQ}" empty "${output_path}" >/dev/null 2>&1; then
		echo "FAIL: output is not valid JSON"
		rm -f "${stdout_path}" "${stderr_path}"
		continue
	fi

	if ! check_sorted_rejected_votes "${output_path}"; then
		echo "FAIL: rejected_votes is not sorted deterministically"
		rm -f "${stdout_path}" "${stderr_path}"
		continue
	fi

	if ! check_sorted_warnings "${output_path}"; then
		echo "FAIL: warnings is not sorted deterministically"
		rm -f "${stdout_path}" "${stderr_path}"
		continue
	fi

	if compare_json_files "${output_path}" "${expected_path}"; then
		echo "PASS"
		PASSED_CASES=$((PASSED_CASES + 1))
	else
		echo "FAIL: output does not match expected JSON"
		echo "  actual:   $(${JQ} -cS '.' "${output_path}")"
		echo "  expected: $(${JQ} -cS '.' "${expected_path}")"
	fi

	rm -f "${stdout_path}" "${stderr_path}"
done

echo ""
echo "=== SUMMARY ==="
echo "${PASSED_CASES}/${TOTAL_CASES} cases passed"

if [ "${PASSED_CASES}" -eq "${TOTAL_CASES}" ]; then
	exit 0
fi

exit 1
