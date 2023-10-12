#!/usr/bin/env bash

################################################################################
################################################################################
########### Super-Linter linting Functions @admiralawkbar ######################
################################################################################
################################################################################
########################## FUNCTION CALLS BELOW ################################
################################################################################
################################################################################
#### Function LintCodebase #####################################################
function LintCodebase() {
  # Call comes through as:
  # LintCodebase "${LANGUAGE}" "${LINTER_NAME}" "${LINTER_COMMAND}" "${FILTER_REGEX_INCLUDE}" "${FILTER_REGEX_EXCLUDE}" "${TEST_CASE_RUN}" "${!LANGUAGE_FILE_ARRAY}"
  ####################
  # Pull in the vars #
  ####################
  FILE_TYPE="${1}" && shift            # Pull the variable and remove from array path  (Example: JSON)
  LINTER_NAME="${1}" && shift          # Pull the variable and remove from array path  (Example: jsonlint)
  LINTER_COMMAND="${1}" && shift       # Pull the variable and remove from array path  (Example: jsonlint -c ConfigFile /path/to/file)
  FILTER_REGEX_INCLUDE="${1}" && shift # Pull the variable and remove from array path  (Example: */src/*,*/test/*)
  FILTER_REGEX_EXCLUDE="${1}" && shift # Pull the variable and remove from array path  (Example: */examples/*,*/test/*.test)
  TEST_CASE_RUN="${1}" && shift        # Flag for if running in test cases
  FILE_ARRAY=("$@")                    # Array of files to validate                    (Example: ${FILE_ARRAY_JSON})

  ##########################
  # Initialize empty Array #
  ##########################
  LIST_FILES=()

  ###################################################
  # Array to track directories where tflint was run #
  ###################################################
  declare -A TFLINT_SEEN_DIRS

  ################
  # Set the flag #
  ################
  SKIP_FLAG=0
  INDEX=0

  # We use these flags to check how many "bad" and "good" test cases we ran
  BAD_TEST_CASES_COUNT=0
  GOOD_TEST_CASES_COUNT=0

  ############################################################
  # Check to see if we need to go through array or all files #
  ############################################################
  if [ ${#FILE_ARRAY[@]} -eq 0 ]; then
    SKIP_FLAG=1
    debug " - No files found in changeset to lint for language:[${FILE_TYPE}]"
  else
    # We have files added to array of files to check
    LIST_FILES=("${FILE_ARRAY[@]}") # Copy the array into list
  fi

  debug "SKIP_FLAG: ${SKIP_FLAG}, list of files to lint: ${LIST_FILES[*]}"

  ###############################
  # Check if any data was found #
  ###############################
  if [ ${SKIP_FLAG} -eq 0 ]; then
    WORKSPACE_PATH="${GITHUB_WORKSPACE}"
    if [ "${TEST_CASE_RUN}" == "true" ]; then
      WORKSPACE_PATH="${GITHUB_WORKSPACE}/${TEST_CASE_FOLDER}"
    fi
    debug "Workspace path: ${WORKSPACE_PATH}"

    ################
    # print header #
    ################
    info ""
    info "----------------------------------------------"
    info "----------------------------------------------"

    debug "Running LintCodebase. FILE_TYPE: ${FILE_TYPE}. Linter name: ${LINTER_NAME}, linter command: ${LINTER_COMMAND}, TEST_CASE_RUN: ${TEST_CASE_RUN}, FILTER_REGEX_INCLUDE: ${FILTER_REGEX_INCLUDE}, FILTER_REGEX_EXCLUDE: ${FILTER_REGEX_EXCLUDE} files to lint: ${FILE_ARRAY[*]}"

    if [ "${TEST_CASE_RUN}" = "true" ]; then
      info "Testing Codebase [${FILE_TYPE}] files..."
    else
      info "Linting [${FILE_TYPE}] files..."
    fi

    info "----------------------------------------------"
    info "----------------------------------------------"

    ##################
    # Lint the files #
    ##################
    for FILE in "${LIST_FILES[@]}"; do
      debug "Linting FILE: ${FILE}"
      ###################################
      # Get the file name and directory #
      ###################################
      FILE_NAME=$(basename "${FILE}" 2>&1)
      DIR_NAME=$(dirname "${FILE}" 2>&1)

      ############################
      # Get the file pass status #
      ############################
      # Example: markdown_good_1.md -> good
      FILE_STATUS=$(echo "${FILE_NAME}" | cut -f2 -d'_')
      # Example: clan_format_good_1.md -> good
      SECONDARY_STATUS=$(echo "${FILE_NAME}" | cut -f3 -d'_')

      ####################################
      # Catch edge cases of double names #
      ####################################
      if [ "${SECONDARY_STATUS}" == 'good' ] || [ "${SECONDARY_STATUS}" == 'bad' ]; then
        FILE_STATUS="${SECONDARY_STATUS}"
      fi

      ###################
      # Check if docker #
      ###################
      if [[ ${FILE_TYPE} == *"DOCKER"* ]]; then
        debug "FILE_TYPE for FILE ${FILE} is related to Docker: ${FILE_TYPE}"
        if [[ ${FILE} == *"good"* ]]; then
          debug "Setting FILE_STATUS for FILE ${FILE} to 'good'"
          #############
          # Good file #
          #############
          FILE_STATUS='good'
        elif [[ ${FILE} == *"bad"* ]]; then
          debug "Setting FILE_STATUS for FILE ${FILE} to 'bad'"
          ############
          # Bad file #
          ############
          FILE_STATUS='bad'
        fi
      fi

      #######################################
      # Check if Cargo.toml for Rust Clippy #
      #######################################
      if [[ ${FILE_TYPE} == *"RUST"* ]] && [[ ${LINTER_NAME} == "clippy" ]]; then
        debug "FILE_TYPE for FILE ${FILE} is related to Rust Clippy: ${FILE_TYPE}"
        if [[ ${FILE} == *"good"* ]]; then
          debug "Setting FILE_STATUS for FILE ${FILE} to 'good'"
          #############
          # Good file #
          #############
          FILE_STATUS='good'
        elif [[ ${FILE} == *"bad"* ]]; then
          debug "Setting FILE_STATUS for FILE ${FILE} to 'bad'"
          ############
          # Bad file #
          ############
          FILE_STATUS='bad'
        fi
      fi

      #########################################################
      # If not found, assume it should be linted successfully #
      #########################################################
      if [ -z "${FILE_STATUS}" ] || { [ "${FILE_STATUS}" != "good" ] && [ "${FILE_STATUS}" != "bad" ]; }; then
        debug "FILE_STATUS (${FILE_STATUS}) is empty, or not set to 'good' or 'bad'. Assuming it should be linted correctly. Setting FILE_STATUS to 'good'..."
        FILE_STATUS="good"
      fi

      INDIVIDUAL_TEST_FOLDER="${FILE_TYPE,,}" # Folder for specific tests. By convention, it's the lowercased FILE_TYPE
      TEST_CASE_DIRECTORY="${TEST_CASE_FOLDER}/${INDIVIDUAL_TEST_FOLDER}"
      debug "File: ${FILE}, FILE_NAME: ${FILE_NAME}, DIR_NAME:${DIR_NAME}, FILE_STATUS: ${FILE_STATUS}, INDIVIDUAL_TEST_FOLDER: ${INDIVIDUAL_TEST_FOLDER}, TEST_CASE_DIRECTORY: ${TEST_CASE_DIRECTORY}"

      if [[ ${FILE_TYPE} != "ANSIBLE" ]]; then
        # These linters expect files inside a directory, not a directory. So we add a trailing slash
        TEST_CASE_DIRECTORY="${TEST_CASE_DIRECTORY}/"
        debug "${FILE_TYPE} expects to lint individual files. Updated TEST_CASE_DIRECTORY to: ${TEST_CASE_DIRECTORY}"
      fi

      if [[ ${FILE} != *"${TEST_CASE_DIRECTORY}"* ]] && [ "${TEST_CASE_RUN}" == "true" ]; then
        debug "Skipping ${FILE} because it's not in the test case directory for ${FILE_TYPE}..."
        continue
      fi

      ##################################
      # Increase the linted file index #
      ##################################
      (("INDEX++"))

      ##############
      # File print #
      ##############
      info "---------------------------"
      info "File:[${FILE}]"

      #################################
      # Add the language to the array #
      #################################
      LINTED_LANGUAGES_ARRAY+=("${FILE_TYPE}")

      ####################
      # Set the base Var #
      ####################
      LINT_CMD=''

      #####################
      # Check for ansible #
      #####################
      if [[ ${FILE_TYPE} == "ANSIBLE" ]]; then
        debug "ANSIBLE_DIRECTORY: ${ANSIBLE_DIRECTORY}, LINTER_COMMAND:${LINTER_COMMAND}, FILE: ${FILE}"
        LINT_CMD=$(
          cd "${ANSIBLE_DIRECTORY}" || exit
          # Don't pass the file to lint to enable ansible-lint autodetection mode.
          # See https://ansible-lint.readthedocs.io/usage for details
          ${LINTER_COMMAND} 2>&1
        )
      ####################################
      # Corner case for pwsh subshell    #
      #  - PowerShell (PSScriptAnalyzer) #
      #  - ARM        (arm-ttk)          #
      ####################################
      elif [[ ${FILE_TYPE} == "POWERSHELL" ]] || [[ ${FILE_TYPE} == "ARM" ]]; then
        ################################
        # Lint the file with the rules #
        ################################
        # Need to run PowerShell commands using pwsh -c, also exit with exit code from inner subshell
        LINT_CMD=$(
          cd "${WORKSPACE_PATH}" || exit
          pwsh -NoProfile -NoLogo -Command "${LINTER_COMMAND} \"${FILE}\"; if (\${Error}.Count) { exit 1 }"
          exit $? 2>&1
        )
      ###############################################################################
      # Corner case for R as we have to pass it to R                                #
      ###############################################################################
      elif [[ ${FILE_TYPE} == "R" ]]; then
        #######################################
        # Lint the file with the updated path #
        #######################################
        if [ ! -f "${DIR_NAME}/.lintr" ]; then
          r_dir="${WORKSPACE_PATH}"
        else
          r_dir="${DIR_NAME}"
        fi
        LINT_CMD=$(
          cd "$r_dir" || exit
          R --slave -e "lints <- lintr::lint('$FILE');print(lints);errors <- purrr::keep(lints, ~ .\$type == 'error');quit(save = 'no', status = if (length(errors) > 0) 1 else 0)" 2>&1
        )
      #########################################################
      # Corner case for C# as it writes to tty and not stdout #
      #########################################################
      elif [[ ${FILE_TYPE} == "CSHARP" ]]; then
        LINT_CMD=$(
          cd "${DIR_NAME}" || exit
          ${LINTER_COMMAND} "${FILE_NAME}" | tee /dev/tty2 2>&1
          exit "${PIPESTATUS[0]}"
        )
      #######################################################
      # Corner case for KTLINT as it cant use the full path #
      #######################################################
      elif [[ ${FILE_TYPE} == "KOTLIN" ]]; then
        LINT_CMD=$(
          cd "${DIR_NAME}" || exit
          ${LINTER_COMMAND} "${FILE_NAME}" 2>&1
        )
      ############################################################################################
      # Corner case for TERRAFORM_TFLINT as it cant use the full path and needs to fetch modules #
      ############################################################################################
      elif [[ ${FILE_TYPE} == "TERRAFORM_TFLINT" ]]; then
        # Check the cache to see if we've already prepped this directory for tflint
        if [[ ! -v "TFLINT_SEEN_DIRS[${DIR_NAME}]" ]]; then
          debug "  Setting up TERRAFORM_TFLINT cache for ${DIR_NAME}"

          TF_DOT_DIR="${DIR_NAME}/.terraform"
          if [ -d "${TF_DOT_DIR}" ]; then
            # Just in case there's something in the .terraform folder, keep a copy of it
            TF_BACKUP_DIR="/tmp/.terraform-tflint-backup${DIR_NAME}"
            debug "  Backing up ${TF_DOT_DIR} to ${TF_BACKUP_DIR}"

            mkdir -p "${TF_BACKUP_DIR}"
            cp -r "${TF_DOT_DIR}" "${TF_BACKUP_DIR}"
            # Store the destination directory so we can restore from our copy later
            TFLINT_SEEN_DIRS[${DIR_NAME}]="${TF_BACKUP_DIR}"
          else
            # Just let the cache know we've seen this before
            TFLINT_SEEN_DIRS[${DIR_NAME}]='false'
          fi

          (
            cd "${DIR_NAME}" || exit
            terraform get >/dev/null
          )
        fi

        LINT_CMD=$(
          cd "${DIR_NAME}" || exit
          ${LINTER_COMMAND} "${FILE_NAME}" 2>&1
        )
      else
        ################################
        # Lint the file with the rules #
        ################################
        LINT_CMD=$(
          cd "${WORKSPACE_PATH}" || exit
          ${LINTER_COMMAND} "${FILE}" 2>&1
        )
      fi
      #######################
      # Load the error code #
      #######################
      ERROR_CODE=$?

      ########################################
      # Check for if it was supposed to pass #
      ########################################
      if [[ ${FILE_STATUS} == "good" ]]; then
        # Increase the good test cases count
        (("GOOD_TEST_CASES_COUNT++"))

        ##############################
        # Check the shell for errors #
        ##############################
        if [ ${ERROR_CODE} -ne 0 ]; then
          debug "Found errors. Error code: ${ERROR_CODE}, File type: ${FILE_TYPE}, Error on missing exec bit: ${ERROR_ON_MISSING_EXEC_BIT}"
          if [[ ${FILE_TYPE} == "BASH_EXEC" ]] && [[ "${ERROR_ON_MISSING_EXEC_BIT}" == "false" ]]; then
            ########
            # WARN #
            ########
            warn "Warnings found in [${LINTER_NAME}] linter!"
            warn "${LINT_CMD}"
          else
            #########
            # Error #
            #########
            error "Found errors in [${LINTER_NAME}] linter!"
            error "Error code: ${ERROR_CODE}. Command output:${NC}\n------\n${LINT_CMD}\n------"
            # Increment the error count
            (("ERRORS_FOUND_${FILE_TYPE}++"))
          fi
        else
          ###########
          # Success #
          ###########
          info " - File:${F[W]}[${FILE_NAME}]${F[B]} was linted with ${F[W]}[${LINTER_NAME}]${F[B]} successfully"
          if [ -n "${LINT_CMD}" ]; then
            info "   - Command output:${NC}\n------\n${LINT_CMD}\n------"
          fi
        fi
      else
        #######################################
        # File status = bad, this should fail #
        #######################################

        # Increase the bad test cases count
        (("BAD_TEST_CASES_COUNT++"))

        ##############################
        # Check the shell for errors #
        ##############################
        if [ ${ERROR_CODE} -eq 0 ]; then
          #########
          # Error #
          #########
          error "Found errors in [${LINTER_NAME}] linter!"
          error "This file should have failed test case!"
          error "Error code: ${ERROR_CODE}. Command output:${NC}\n------\n${LINT_CMD}\n------"
          # Increment the error count
          (("ERRORS_FOUND_${FILE_TYPE}++"))
        else
          ###########
          # Success #
          ###########
          info " - File:${F[W]}[${FILE_NAME}]${F[B]} failed test case (Error code: ${ERROR_CODE}) with ${F[W]}[${LINTER_NAME}]${F[B]} successfully"
        fi
      fi
      debug "Error code: ${ERROR_CODE}. Command output:${NC}\n------\n${LINT_CMD}\n------"
    done
  fi

  # Clean up after TFLINT
  for TF_DIR in "${!TFLINT_SEEN_DIRS[@]}"; do
    (
      cd "${TF_DIR}" || exit
      rm -rf .terraform

      # Check to see if there was a .terraform folder there before we got started, restore it if so
      POTENTIAL_BACKUP_DIR="${TFLINT_SEEN_DIRS[${TF_DIR}]}"
      if [[ "${POTENTIAL_BACKUP_DIR}" != 'false' ]]; then
        # Put the copy back in place
        debug "  Restoring ${TF_DIR}/.terraform from ${POTENTIAL_BACKUP_DIR}"
        mv "${POTENTIAL_BACKUP_DIR}/.terraform" .terraform
      fi
    )
  done

  if [ "${TEST_CASE_RUN}" = "true" ]; then

    debug "The ${LINTER_NAME} (linter: ${LINTER_NAME}) test suite has ${INDEX} test, of which ${BAD_TEST_CASES_COUNT} 'bad' (supposed to fail), ${GOOD_TEST_CASES_COUNT} 'good' (supposed to pass)."

    # Check if we ran at least one test
    if [ "${INDEX}" -eq 0 ]; then
      error "Failed to find any tests ran for the Linter:[${LINTER_NAME}]!"
      fatal "Validate logic and that tests exist for linter: ${LINTER_NAME}"
    fi

    # Check if we ran 'bad' tests
    if [ "${BAD_TEST_CASES_COUNT}" -eq 0 ]; then
      if [ "${FILE_TYPE}" = "ANSIBLE" ]; then
        debug "There are no 'bad' tests for ${FILE_TYPE}, but it's a corner case that we allow because ${LINTER_NAME} is supposed to lint entire directories and the test suite doesn't support this corner case for 'bad' tests yet."
      else
        error "Failed to find any tests that are expected to fail for the Linter:[${LINTER_NAME}]!"
        fatal "Validate logic and that tests that are expected to fail exist for linter: ${LINTER_NAME}"
      fi
    fi

    # Check if we ran 'good' tests
    if [ "${GOOD_TEST_CASES_COUNT}" -eq 0 ]; then
      error "Failed to find any tests that are expected to pass for the Linter:[${LINTER_NAME}]!"
      fatal "Validate logic and that tests that are expected to pass exist for linter: ${LINTER_NAME}"
    fi
  fi
}
