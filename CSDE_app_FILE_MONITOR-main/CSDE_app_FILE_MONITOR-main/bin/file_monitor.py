#!/ds/CENTOS/python3/bin/python

import pathlib
import re
from datetime import datetime, date
from datetime import time
import getopt
import os
import sys

from DS.Build import Build
from file_config import FileConfig

# Define globals
PGM = None
LOGGER = None
DB_CONNECTION = None
BUILD_OBJ = None

DEFAULT_EMAIL_NOTIFICATION_ADDRESS = None
INBOUND_DEFAULT_PROCESSED_FOLDER = None
INBOUND_DEFAULT_FAILED_FOLDER = None
OUTBOUND_DEFAULT_PROCESSED_FOLDER = None
OUTBOUND_DEFAULT_FAILED_FOLDER = None
NUMBER_OF_FAILED_ATTEMPTS = ""
DEFAULT_CUTOFF_TIME = None
DEFAULT_FILE_DATE_QUALIFIER = None
CONFIG_TABLE = None
ATTEMPT_STATUS_TABLE = None
STATUS_LOG_TABLE = None
DEFAULT_NOTIFY_THROUGH_EMAIL = None
DEFAULT_NOTIFY_THROUGH_DSLOG = None

command_line_debug = 'INFO'
FILE_GROUP = None

VALID_FILE_DATE_QUALIFIER = ['today', 'yesterday', 'tomorrow', 'last_month_begin', 'last_month_end',
                             'last_month', 'this_month', 'next_month']
VALID_NOTIFICATION_VALUES = ["Y", "N"]


def usage():
    """
    Display usage to console screen.

    Args:
        None

    Returns:
        None

    Raises:
        None
    """
    verbiage = """
    Usage: {pgm_name} [-options]

    Options:  
        --file-group or -g    => For example, '--file-group SSRX_PC'. This will monitor any files associated with this 
                                 group. Currently only one value is accepted.
        --debug      or -d    => Increase the logging level to DEBUG
        --help       or -h    => Display help message and exit
       """
    print(verbiage.format(pgm_name=PGM))


def get_opts():
    """
    Get command line parameters.

    -g, --file-group    File group to be monitored. For example, SSRX_PC. This will monitor any files associated with
                        this group. Currently only one value is accepted.
    -d, --debug         Display Debug level logging information
    -h, --help          Displays help

    Args:
        None

    Returns:
        None

    Raises:
        None
    """

    global command_line_debug
    global FILE_GROUP

    try:
        optlist, args = getopt.getopt(
            sys.argv[1:],
            'gdh',  # shorthand options
            [
                'file-group=', 'debug', 'help'
            ]  # longhand options
        )
    except getopt.GetoptError as err:
        print(str(err))
        usage()
        sys.exit(0)

    command_line_debug = 'INFO'

    for o, a in optlist:
        if o in ("-d", "--debug"):
            command_line_debug = 'DEBUG'
        elif o in ("-g", "--file-group"):
            FILE_GROUP = a
        elif o in ("-h", "--help"):
            usage()
            sys.exit(0)

    # Return all command line arguments that were not parsed.
    if args:
        print(f"Unknown parameter(s) {args}\n")
        usage()
        exit(0)

    return


# noinspection PyUnresolvedReferences,PyUnresolvedReferences,PyUnresolvedReferences
def abend_pgm(message):
    """
    Exit the application.

    This method is called in response to any exception thrown in the application.
    Close database connection. Added entry to DS_LOG table. Exit method called doesn't
    exist the application rather it throws SystemExit exception which is caught by main method

    Args:
        message (str): Message value to be inserted to DSLOG.

    Returns:
        int: 0

    Raises:
        SystemError: Automatically raised by the sys.exit() method
    """
    if DB_CONNECTION:
        DB_CONNECTION.rollback()
        DB_CONNECTION.close()

    if LOGGER:
        LOGGER.error(f"{message} - All changes rolled back.")
    else:
        sys.stderr.write(f"{message}\nAll changes rolled back.\n")

    # Add entry to DS_LOG
    BUILD_OBJ.log_monitoring('FAILED', message, 'ERROR')

    # Following exit call will throw SystemError exception. In main method, the BaseException
    # is handled to exit the application
    sys.exit()


def end_pgm(message):
    """
    Exit the application.

    This method is called for a non-error exit from the application.
    Close database connection. Added entry to DS_LOG table. Exit method called doesn't
    exist the application rather it throws SystemExit exception which is caught by main method

    Args:
        message (str): Message value to be inserted to DSLOG.

    Returns:
        int: 0

    Raises:
        SystemError: Automatically raised by the sys.exit() method
    """
    # TODO: could be part of build package
    if DB_CONNECTION:
        DB_CONNECTION.close()

    if LOGGER:
        LOGGER.info(f"{message}")
    else:
        print(f"{message}\n")

    # Add entry to DS_LOG
    BUILD_OBJ.log_monitoring('SUCCESS', message, 'INFO')

    # Following exit call will throw SystemError exception. In main method, the BaseException is handled to exit
    # the application
    if message == "Done.":
        sys.exit(message)
    else:
        sys.exit()


def get_config():
    """
    Get default values from build_config.xml file.

    This method is called to load default values from build_config.xml file.

    Args:
        None

    Returns:
        None

    Raises:
        None
    """
    global DEFAULT_EMAIL_NOTIFICATION_ADDRESS
    global INBOUND_DEFAULT_PROCESSED_FOLDER
    global INBOUND_DEFAULT_FAILED_FOLDER
    global OUTBOUND_DEFAULT_PROCESSED_FOLDER
    global OUTBOUND_DEFAULT_FAILED_FOLDER
    global NUMBER_OF_FAILED_ATTEMPTS
    global DEFAULT_CUTOFF_TIME
    global CONFIG_TABLE
    global ATTEMPT_STATUS_TABLE
    global STATUS_LOG_TABLE
    global DEFAULT_NOTIFY_THROUGH_EMAIL
    global DEFAULT_NOTIFY_THROUGH_DSLOG
    global DEFAULT_FILE_DATE_QUALIFIER

    DEFAULT_EMAIL_NOTIFICATION_ADDRESS = BUILD_OBJ.get_config('default_email_notification_address')
    if DEFAULT_EMAIL_NOTIFICATION_ADDRESS is None or DEFAULT_EMAIL_NOTIFICATION_ADDRESS.strip() == "":
        DEFAULT_EMAIL_NOTIFICATION_ADDRESS= "Y"

    INBOUND_DEFAULT_PROCESSED_FOLDER = BUILD_OBJ.get_config('inbound_default_processed_folder')
    if INBOUND_DEFAULT_PROCESSED_FOLDER is None or INBOUND_DEFAULT_PROCESSED_FOLDER.strip() == "":
        INBOUND_DEFAULT_PROCESSED_FOLDER = ".processed"

    INBOUND_DEFAULT_FAILED_FOLDER = BUILD_OBJ.get_config('inbound_default_failed_folder')
    if INBOUND_DEFAULT_FAILED_FOLDER is None or INBOUND_DEFAULT_FAILED_FOLDER.strip() == "":
        INBOUND_DEFAULT_FAILED_FOLDER = ".failed"

    OUTBOUND_DEFAULT_PROCESSED_FOLDER = BUILD_OBJ.get_config('outbound_default_processed_folder')
    if OUTBOUND_DEFAULT_PROCESSED_FOLDER is None or OUTBOUND_DEFAULT_PROCESSED_FOLDER.strip() == "":
        OUTBOUND_DEFAULT_PROCESSED_FOLDER = ".processed"

    OUTBOUND_DEFAULT_FAILED_FOLDER = BUILD_OBJ.get_config('outbound_default_failed_folder')
    if OUTBOUND_DEFAULT_FAILED_FOLDER is None or OUTBOUND_DEFAULT_FAILED_FOLDER.strip() == "":
        OUTBOUND_DEFAULT_FAILED_FOLDER = ".failed"

    NUMBER_OF_FAILED_ATTEMPTS = BUILD_OBJ.get_config('number_of_failure_attempts')
    if NUMBER_OF_FAILED_ATTEMPTS is None or NUMBER_OF_FAILED_ATTEMPTS.strip() == "":
        NUMBER_OF_FAILED_ATTEMPTS = 3

    DEFAULT_CUTOFF_TIME = BUILD_OBJ.get_config('default_cutoff_time')
    if DEFAULT_CUTOFF_TIME is None or DEFAULT_CUTOFF_TIME.strip() == "":
        DEFAULT_CUTOFF_TIME = "03:00:00"

    CONFIG_TABLE = BUILD_OBJ.get_config('db_file_monitor_config_tbl')
    if CONFIG_TABLE is None or CONFIG_TABLE.strip() == "":
        CONFIG_TABLE = "FILE_MONITOR_CONFIG"

    ATTEMPT_STATUS_TABLE = BUILD_OBJ.get_config('db_file_monitor_attempt_status_tbl')
    if ATTEMPT_STATUS_TABLE is None or ATTEMPT_STATUS_TABLE.strip() == "":
        ATTEMPT_STATUS_TABLE = "FILE_MONITOR_ATTEMPT_STATUS"

    STATUS_LOG_TABLE = BUILD_OBJ.get_config('db_file_monitor_status_log_tbl')
    if STATUS_LOG_TABLE is None or STATUS_LOG_TABLE.strip() == "":
        STATUS_LOG_TABLE = "FILE_MONITOR_STATUS_LOG"

    DEFAULT_NOTIFY_THROUGH_EMAIL = BUILD_OBJ.get_config('default_email_notification_option')
    if DEFAULT_NOTIFY_THROUGH_EMAIL is None or DEFAULT_NOTIFY_THROUGH_EMAIL.strip() == "":
        DEFAULT_NOTIFY_THROUGH_EMAIL= "Y"

    DEFAULT_NOTIFY_THROUGH_DSLOG = BUILD_OBJ.get_config('default_dslog_interface_option')
    if DEFAULT_NOTIFY_THROUGH_DSLOG is None or DEFAULT_NOTIFY_THROUGH_DSLOG.strip() == "":
        DEFAULT_NOTIFY_THROUGH_DSLOG= "Y"

    DEFAULT_FILE_DATE_QUALIFIER = BUILD_OBJ.get_config('default_file_date_qualifier')
    if DEFAULT_FILE_DATE_QUALIFIER is None or DEFAULT_FILE_DATE_QUALIFIER.strip() == "":
        DEFAULT_FILE_DATE_QUALIFIER = "today"

def get_actual_filename(file_config):
    """
    Constructs actual file name.

    This method is called to construct actual file name based on date qualifier. Converts the YYYYMMDD string to
    Python date format string (Ymd). Replaces the date format with actual date value. After creating the actual
    filename, adds it to file_config object.

    Args:
        file_config (file_config) : File Config object

    Returns:
        None

    Raises:
        None
    """
    date_format_in_filename = re.search('%s(.*)%s' % ("{", "}"), file_config.file_name).group(1)
    converted_date_format = (date_format_in_filename.replace("YYYY", "%Y")
                             .replace("YY", "%y")
                             .replace("MM", "%m")
                             .replace("DD", "%d"))

    date_value = BUILD_OBJ.get_date(file_config.file_date_qualifier)
    if converted_date_format != "%Y%m%d":
        temp_date_value = datetime.strptime(date_value, "%Y%m%d")
        formated_date_value = temp_date_value.strftime(converted_date_format)
    else:
        formated_date_value = date_value
    actual_filename = re.sub(r'(\b{).*(\b})', formated_date_value, file_config.file_name)
    file_config.actual_filename = actual_filename


def send_notification(event_code, log_message, log_level, file_config):
    """
    Send DSLOG notifications..

    This method is called to send DSLOG notifications. DSLOG entry is created only when the notification through
    DSLOG option is set to 'Y'

    Args:
        event_code (str) : Process status
        message (str) : Detailed notification message
        log_level (str) : Log level for DS_LOG
        file_config (file_config) : Contains notification indicator

    Returns:
        None

    Raises:
        None
    """
    # if file_config.notify_through_email == "Y":
    #     BUILD_OBJ.send_html_custom_email(status, file_config, message, schema_name, table_name)

    if file_config.notify_through_dslog == "Y":
        log_message += f"<br><br>Custom Notification Message:<br> {file_config.custom_notification_message}"
        BUILD_OBJ.log_monitoring(event_code, log_message, log_level)


def get_file_config_data(file_config_map):
    """
    Get files to be monitored from FILE_MONITOR_CONFIG table.

    Logic to load the files to be monitored.
    1. Get records from FILE_MONITOR_CONFIG.
    2. Validate empty or NULL fields and replace with default values.
    3. Validate cutoff time. It should be in HH24:MM:SS if not send notification and quit the program
    4. Based on the FILE_MONITOR_CONFIG.FILE_DATE_QUALIFIER value, replace the date placeholder on the filename.
        a. If FILE_MONITOR_CONFIG.FILE_DATE_QUALIFIER value not found in VALID_FILE_DATE_QUALIFIER, send
           notification and quit the program

    Args:
        file_config (file_config) : File Config object

    Returns:
        None

    Raises:
        None
    """
    file_config_sql = f"""
                        select 
                            fmr.FILE_GROUP, 
                            fmr.PROCESS,
                            fmr.PROCESS_DESCRIPTION, 
                            fmr.FILE_NAME,  
                            fmr.FILE_DATE_QUALIFIER, 
                            fmr.FILE_CUTOFF_TIME,                  
                            fmr.FILE_TYPE, 
                            fmr.FILE_INBOUND_FOLDER,          
                            fmr.FILE_INBOUND_PROCESSED_FOLDER, 
                            fmr.FILE_INBOUND_FAILED_FOLDER,    
                            fmr.FILE_OUTBOUND_FOLDER,          
                            fmr.FILE_OUTBOUND_PROCESSED_FOLDER,
                            fmr.FILE_OUTBOUND_FAILED_FOLDER, 
                            fmr.NUMBER_OF_FAILURE_ATTEMPT,
                            fmr.NOTIFY_THROUGH_EMAIL,
                            fmr.FAILURE_EMAIL,                
                            fmr.NOTIFY_THROUGH_DSLOG,           
                            fmr.CUSTOM_VALIDATION_SCRIPT,                  
                            fmr.CUSTOM_NOTIFICATION_MESSAGE,   
                            fmr.ENTRY_DATE,                    
                            fmr.ENTERED_BY,
                            fmr.MONITOR_ENABLED_IND
                        from {CONFIG_TABLE} fmr
                        left outer join (select * from {STATUS_LOG_TABLE} where event_date = trunc(SYSDATE)) fms
                        ON fmr.FILE_GROUP = fms.FILE_GROUP
                            AND fmr.FILE_NAME = fms.FILE_NAME
                        WHERE 
                            fms.FILE_GROUP is null
                            AND fms.FILE_NAME is null
                            AND (trim(fmr.MONITOR_ENABLED_IND) = 'Y' or trim(fmr.MONITOR_ENABLED_IND) = 'y')
                    """

    if FILE_GROUP is not None:
        file_config_sql += f" AND fmr.FILE_GROUP = '{FILE_GROUP}'"

    LOGGER.debug(f"Executing {file_config_sql}")

    try:
        csr = DB_CONNECTION.cursor()
        csr.execute(file_config_sql)
        result = csr.fetchall()

        for row in result:
            error_config_msg_list = []
            is_date_qualifier_correct = True
            file_config = FileConfig()

            file_config.file_group = row[0].strip()
            file_config.process = row[1].strip()
            file_config.process_description = row[2].strip()
            file_config.file_name = row[3].strip()

            # Load email and DSLOG notification status. This is required before other data loading
            # to notify correctly when downstream failure happens.
            # NOTIFY_THROUGH_EMAIL
            if row[14] is None or row[14].strip() == "":
                file_config.notify_through_email = DEFAULT_NOTIFY_THROUGH_EMAIL
            else:
                file_config.notify_through_email = row[14].upper()

            # NOTIFY_THROUGH_DSLOG
            if row[16] is None or row[16].strip() == "":
                file_config.notify_through_dslog = DEFAULT_NOTIFY_THROUGH_DSLOG
            else:
                val = row[16].upper()
                if val not in VALID_NOTIFICATION_VALUES:
                    message = (
                        f"File Configuration error: Invalid value '{row[16]}' for notify through DSLOG. "
                        f"Value found in column FILE_MONITOR_CONFIG.NOTIFY_THROUGH_DSLOG. Valid values are "
                        f"{VALID_NOTIFICATION_VALUES}.")
                    LOGGER.error(message)
                    error_config_msg_list.append(message)
                    file_config.notify_through_dslog = DEFAULT_NOTIFY_THROUGH_DSLOG
                else:
                    file_config.notify_through_dslog = val

            # Validate file date replacement qualifier
            # FILE_DATE_QUALIFIER
            if row[4] is None or row[4].strip() == "":
                file_config.file_date_qualifier = DEFAULT_FILE_DATE_QUALIFIER
            else:
                date_qualifier = row[4].strip().lower()
                if date_qualifier not in VALID_FILE_DATE_QUALIFIER:
                    is_date_qualifier_correct = False
                    message = (
                        f"File Configuration error: Invalid file date qualifier '{row[4]}'. "
                        f"Value found in column FILE_MONITOR_CONFIG.FILE_DATE_QUALIFIER. Valid values are "
                        f"{VALID_FILE_DATE_QUALIFIER}.")
                    LOGGER.error(message)
                    error_config_msg_list.append(message)
                else:
                    file_config.file_date_qualifier = date_qualifier

            # Validate cut-off time
            # FILE_CUTOFF_TIME
            if row[5] is None or row[5].strip() == "":
                file_config.file_cutoff_time = datetime.strptime(DEFAULT_CUTOFF_TIME, "%H:%M:%S")
            else:
                # Validate time in HH24:MM:SS format
                try:
                    file_config.file_cutoff_time = datetime.strptime(row[5].strip(), "%H:%M:%S")
                except ValueError:
                    message = (
                        f"File Configuration error: Invalid time '{row[5]}'. "
                        f"Value found in column FILE_MONITOR_CONFIG.FILE_CUTOFF_TIME. Time should be in "
                        f"HH24:MM:SS format.")
                    LOGGER.error(message)
                    error_config_msg_list.append(message)

            # FILE_TYPE
            if row[6] is not None:
                file_config.file_type = row[6].strip()

            # FILE_INBOUND_FOLDER
            if row[7] is not None:
                file_config.file_inbound_folder = row[7].strip()

            # FILE_OUTBOUND_FOLDER
            if row[10] is not None:
                file_config.file_outbound_folder = row[10].strip()

            # Validate inbound or outbound folder names are specified
            if (file_config.file_inbound_folder is None or file_config.file_inbound_folder == "") and \
                    (file_config.file_outbound_folder is None or file_config.file_outbound_folder == ""):
                message = (
                    f"File Configuration error: Inbound folder name and outbound folder name are empty. "
                    f"Folder name should be specified for inbound or outbound. "
                    f"Update column FILE_MONITOR_CONFIG.FILE_INBOUND_FOLDER or FILE_MONITOR_CONFIG.FILE_OUTBOUND_FOLDER")
                LOGGER.error(message)
                error_config_msg_list.append(message)
            else:
                # FILE_INBOUND_PROCESSED_FOLDER
                if row[8] is None or row[8].strip() == "":
                    if (file_config.file_inbound_folder is not None) and file_config.file_inbound_folder:
                        file_config.file_inbound_processed_folder = (file_config.file_inbound_folder + os.sep +
                                                                     INBOUND_DEFAULT_PROCESSED_FOLDER)
                else:
                    file_config.file_inbound_processed_folder = row[8].strip()

                # FILE_INBOUND_FAILED_FOLDER
                if row[9] is None or row[9].strip() == "":
                    if (file_config.file_inbound_folder is not None) and file_config.file_inbound_folder:
                        file_config.file_inbound_failed_folder = (file_config.file_inbound_folder + os.sep +
                                                                  INBOUND_DEFAULT_FAILED_FOLDER)
                else:
                    file_config.file_inbound_failed_folder = row[9].strip()

                # FILE_OUTBOUND_PROCESSED_FOLDER
                if row[11] is None or row[11].strip() == "":
                    if (file_config.file_outbound_folder is not None) and file_config.file_outbound_folder:
                        file_config.file_outbound_processed_folder = (file_config.file_outbound_folder + os.sep +
                                                                      OUTBOUND_DEFAULT_PROCESSED_FOLDER)
                else:
                    file_config.file_outbound_processed_folder = row[11].strip()

                # FILE_OUTBOUND_FAILED_FOLDER
                if row[12] is None or row[12].strip() == "":
                    if (file_config.file_outbound_folder is not None) and file_config.file_outbound_folder:
                        file_config.file_outbound_failed_folder = (file_config.file_outbound_folder + os.sep +
                                                                   OUTBOUND_DEFAULT_FAILED_FOLDER)
                else:
                    file_config.file_outbound_failed_folder = row[12].strip()

            # Validate number of failed attempts
            # NUMBER_OF_FAILURE_ATTEMPT
            if row[13] is None:
                file_config.number_of_failed_attempt = int(NUMBER_OF_FAILED_ATTEMPTS)
            else:
                file_config.number_of_failed_attempt = int(row[13])

            # CUSTOM_VALIDATION_SCRIPT
            if row[17] is not None:
                file_config.custom_validation_script = row[17].strip()

            # CUSTOM_NOTIFICATION_MESSAGE
            if row[18] is not None:
                file_config.custom_notification_message = row[18].strip()

            # ENTRY_DATE
            if row[19] is not None:
                file_config.entry_date = row[19]

            # ENTERED_BY
            if row[20] is not None:
                file_config.entered_by = row[20].strip()

            # MONITOR_ENABLED_IND. This is part of query where clause. Qualified record will always have 'Y' or 'y'
            if row[21] is not None:
                file_config.monitor_enabled_ind = row[21].upper()

            # derived fields
            if is_date_qualifier_correct:
                get_actual_filename(file_config)

            # if there are any errors loading the record, send a notification and continue processing other records
            if len(error_config_msg_list) > 0:
                file_config.final_folder_name = "N/A"
                file_config.actual_filename = file_config.file_name
                err_msg = (
                    f"<br>For file group '{file_config.file_group}' and file name '{file_config.file_name}', following "
                    f"configuration errors were reported. This file will not be monitored. <br>")
                err_msg += "<ol>" + "".join(f'<li>{element}</li>' for element in error_config_msg_list) + "</ol>"
                LOGGER.error(err_msg)
                send_notification("FAILED", err_msg, "ERROR", file_config )
                # Update status log
                update_status_log(file_config, "CONFIG FAILED", err_msg)

                continue

            LOGGER.debug(file_config)

            file_list = file_config_map.get(file_config.file_group)
            if file_list is None:
                file_config_map[file_config.file_group] = [file_config]
            else:
                file_list.append(file_config)

    except BaseException as be:
        LOGGER.fatal(be)
        abend_pgm(f"Exception encountered attempting to fetch data from table {CONFIG_TABLE}")
    finally:
        csr.close()


def update_status_log(file_config, status, message):
    """
    Update the status for each file.

    Update each file status to FILE_MONITOR_STATUS_LOG table. Following as possible status:
        SUCCESSFUL - File found in processed folder
        FAILED - File found in failed folder
        MONITOR FAILED - file not processed OR file never received/created
        CONFIG FAILED - Configuration error

    Args:
        file_config (file_config) : File Config object
        status (str) : Monitored file status (SUCCESSFUL, FAILED, MONITOR FAILED, CONFIG FAILED)
        message (str) : Status message

    Returns:
        None

    Raises:
        None
    """
    notification_status = ""
    status_sql = f"""
            INSERT INTO {STATUS_LOG_TABLE} (
                  EVENT_DATE,
                  FILE_GROUP,
                  FILE_FOLDER,
                  FILE_NAME,
                  ACTUAL_FILE_NAME,
                  MONITOR_STATUS,
                  MESSAGE,
                  IS_NOTIFICATION_SENT,
                  NOTIFICATION_SENT_DATE
                ) VALUES (
                  TO_DATE(:v_event_date,'YYYYMMDD'),
                  :v_file_group,
                  :v_file_folder,
                  :v_registry_file_name,
                  :v_actual_file_name,
                  :v_monitor_status,
                  :v_message,
                  :v_notification_sent,
                  TO_TIMESTAMP(:v_event_date,'YYYY-MM-DD HH24:MI:SS.FF6')
                )
        """
    if "FAILED" in status:
        notification_status = "Y"

    status_params = [BUILD_OBJ.today, file_config.file_group, file_config.final_folder_name,
                     file_config.file_name, file_config.actual_filename, status, message, notification_status,
                     datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')]
    LOGGER.debug(f"Executing {status_sql}")
    LOGGER.debug(f"Parameters: {status_params}")
    try:
        with DB_CONNECTION.cursor() as cursor:
            cursor.execute(status_sql, status_params)
            DB_CONNECTION.commit()

    except Exception as error:
        err, = error.args
        err_message = f'Error code : {err.code}, messsage : {err.message}'
        LOGGER.error(err_message)


def get_failed_attempt_count(file_config):
    """
    Get monitoring failed attempts for a file.

    Get number of failed attempts for given run date, group and file name

    Args:
        file_config (file_config) : File Config object

    Returns:
        None

    Raises:
        None
    """
    attempt_count = 0
    get_attempt_sql = f"""
                      SELECT
                        NUMBER_OF_ATTEMPT
                      FROM
                        {ATTEMPT_STATUS_TABLE}
                      WHERE
                        RUN_DATE = TO_DATE(:v_run_date,'YYYYMMDD')
                        AND FILE_GROUP = :v_file_group
                        AND FILE_NAME = :v_file_name
                    """

    LOGGER.debug(f"Executing {get_attempt_sql}")
    LOGGER.debug(f"Parameters: {[BUILD_OBJ.today, file_config.file_group, file_config.actual_filename]}")
    try:
        with DB_CONNECTION.cursor() as cursor:
            cursor.execute(get_attempt_sql, [BUILD_OBJ.today, file_config.file_group, file_config.actual_filename])
            number_of_attempts = cursor.fetchone()
    except Exception as error:
        err, = error.args
        err_message = f'Error code : {err.code}, messsage : {err.message}'
        LOGGER.error(err_message)

    if number_of_attempts is None:
        attempt_count = 0
    else:
        attempt_count = number_of_attempts[0]

    return attempt_count


def update_failed_attempt_count(failed_attempts, file_config):
    """
    Create or Update failed attempt count.

    If record found for run date, group and file name combination, update the failed attempts.
    If record not found, insert a new record with failed count '1'

    Args:
        failed_attempts (int) : Number of failed attempts
        file_config (file_config) : File Config object

    Returns:
        None

    Raises:
        None
    """
    update_insert_attempt_sql = f"""
                        MERGE INTO {ATTEMPT_STATUS_TABLE}   
                        USING DUAL  
                        ON    ( RUN_DATE = TO_DATE('{BUILD_OBJ.today}','YYYYMMDD')
                                AND FILE_GROUP = '{file_config.file_group}'
                                AND FILE_NAME = '{file_config.actual_filename}')  
                        WHEN NOT MATCHED THEN   
                            INSERT (RUN_DATE,FILE_GROUP,FILE_NAME, NUMBER_OF_ATTEMPT ) 
                            VALUES (TO_DATE('{BUILD_OBJ.today}','YYYYMMDD'), '{file_config.file_group}', 
                            '{file_config.actual_filename}', 1 )  
                        WHEN MATCHED THEN   
                            UPDATE  
                            SET NUMBER_OF_ATTEMPT = {failed_attempts}
                    """
    LOGGER.debug(update_insert_attempt_sql)
    try:
        with DB_CONNECTION.cursor() as cursor:
            cursor.execute(update_insert_attempt_sql)
            DB_CONNECTION.commit()
    except Exception as error:
        err, = error.args
        err_message = f'Error code : {err.code}, messsage : {err.message}'
        LOGGER.error(err_message)


def perform_validation_and_update(bound, file_config, current_time):
    """
    Check the file status on the file system.

    Logic:
    1. Based on inbound or outbound, get the absolute file name, absolute processed filename and
        absolute failed filename
    2. If file found in processed folder, update the status log table with 'SUCCESSFUL' status
    3. If file found in failed folder, send the notification (Email and/or DSLOG). update the status
        log table with 'FAILED' status. Increment failed file counter by 1. Append failed process name to
        failed process list.
    4. Get the cut-off time and compare with current time. If current time is earlier than cut-off time, continue
        with processing next file.
    5. If current time is later than cut-off time, check the file existence in root folder. If file exist or not found,
        get the current failed attempt count from 'FILE_MONITOR_ATTEMPT_STATUS' table. If the count is less than
        max failed attempts, increase the value by 1 and update the failed count.
        If the count is greater than max failed attempts, send the notification (Email and/or DSLOG). update the status
        log table with 'MONITOR FAILED' status. Append failed process name to failed process list.


    Args:
        bound (str) : Value with "inbound' or "outbound"
        file_config (file_config) : File Config object
        current_time (time) : Current time to check cut-off

    Returns:
        None

    Raises:
        None
    """
    absolute_processed_filename = None
    absolute_failed_filename = None
    absolute_filename = None

    if bound == "inbound":
        absolute_filename = file_config.file_inbound_folder + os.sep + file_config.actual_filename
        absolute_processed_filename = (file_config.file_inbound_processed_folder +
                                       os.sep + file_config.actual_filename)
        absolute_failed_filename = (file_config.file_inbound_failed_folder +
                                    os.sep + file_config.actual_filename)

    if bound == "outbound":
        absolute_filename = file_config.file_outbound_folder + os.sep + file_config.actual_filename
        absolute_processed_filename = (file_config.file_outbound_processed_folder +
                                       os.sep + file_config.actual_filename)
        absolute_failed_filename = (file_config.file_outbound_failed_folder +
                                    os.sep + file_config.actual_filename)

    # If file found in either processed or failed, don't process other folder location
    # Check processed folder
    file_exist = os.path.isfile(absolute_processed_filename)
    if file_exist:
        LOGGER.info(f"File '{absolute_processed_filename}' found in processed folder.")
        file_config.final_folder_name = str(pathlib.Path(absolute_processed_filename).parent)
        update_status_log(file_config, "SUCCESSFUL", "")
        return

    # Check failed folder
    file_exist = os.path.isfile(absolute_failed_filename)
    if file_exist:
        message = f"File '{absolute_failed_filename}' found in failed folder."
        LOGGER.error(message)
        file_config.final_folder_name = str(pathlib.Path(absolute_failed_filename).parent)
        send_notification("FAILED", message, "ERROR", file_config)
        update_status_log(file_config, "FAILED", message)
        return

    # Check cut-off time passed
    if current_time < file_config.file_cutoff_time.time():
        return

    # Check root folder
    file_found = False
    file_exist = os.path.isfile(absolute_filename)
    if file_exist:
        file_found = True
        LOGGER.info(f'After cut-off time ({file_config.file_cutoff_time.strftime("%H:%M:%S")}), '
                    f'file "{file_config.actual_filename}" found in root folder.')
    else:
        LOGGER.info(f'After cut-off time ({file_config.file_cutoff_time.strftime("%H:%M:%S")}), '
                    f'file "{file_config.actual_filename}" NOT in root folder.')

    failed_attempts = get_failed_attempt_count(file_config)
    if failed_attempts < file_config.number_of_failed_attempt:
        failed_attempts += 1
        LOGGER.error(f"Total number of failed attempts for the file '{absolute_filename}' "
                     f"is '{file_config.number_of_failed_attempt}'. Current failed attempt count "
                     f"is '{failed_attempts}'.")
        update_failed_attempt_count(failed_attempts, file_config)
    else:
        if file_found:
            message = f"File '{absolute_filename}' not being processed after {failed_attempts} verification attempts."
        else:
            message = f"File '{absolute_filename}' NOT found/received after {failed_attempts} verification attempts."
        file_config.final_folder_name = str(pathlib.Path(absolute_filename).parent)
        LOGGER.error(message)
        send_notification("FAILED", message, "ERROR", file_config)
        update_status_log(file_config, "MONITOR FAILED", message)


def process_file_monitoring(file_config_list, current_time):
    """
    This method identifies the inbound and outbound processing.

    If inbound folder name specified for the file, it is considered "inbound" processing.
    If outbound folder name specified for the file, it is considered "outbound" processing.

    Args:
        file_config (file_config) : File Config object
        current_time (time) : Current time to check cut-off

    Returns:
        None

    Raises:
        None
    """
    processing_folder = None

    for file_config in file_config_list:

        LOGGER.info(f"Processing '{file_config.file_group}' and '{file_config.file_name}' .......")

        # Process inbound validation
        if (file_config.file_inbound_folder is not None
                and len(file_config.file_inbound_folder.strip()) != 0):
            processing_folder = "inbound"
        elif (file_config.file_outbound_folder is not None
              and len(file_config.file_outbound_folder.strip()) != 0):
            processing_folder = "outbound"

        perform_validation_and_update(processing_folder, file_config, current_time)


def run_monitoring(file_config_map):
    """
    This method checks whether to process file group passed through command line.

    If name of the file group passed through command line, only process the files associated with this file group

    Args:
        file_config (file_config) : File Config object

    Returns:
        None

    Raises:
        None
    """
    current_time = datetime.now().time()
    selected_file_config_list = []

    # Check group name passed in command line
    if FILE_GROUP is not None:
        LOGGER.debug(f"Processing File Group '{FILE_GROUP}'")
        LOGGER.info(f"Found {len(file_config_map[FILE_GROUP])} configuration data for the File Group '{FILE_GROUP}'")
        process_file_monitoring(file_config_map[FILE_GROUP], current_time)
    else:
        for file_group_key, file_config_list in file_config_map.items():
            LOGGER.debug(f"Processing File Group '{file_group_key}'")
            LOGGER.info(f"Found {len(file_config_list)} configuration data for the File Group '{file_group_key}'")
            process_file_monitoring(file_config_list, current_time)


def get_config_tbl_data():
    """
    Get file monitoring configuration table data.

    Get files to be monitored with other configuration information

    Args:
        None

    Returns:
        None

    Raises:
        None
    """
    get_config_tbl_data_sql = f"""SELECT * FROM {CONFIG_TABLE}"""

    LOGGER.debug(f"Executing {get_config_tbl_data_sql}")

    try:
        with DB_CONNECTION.cursor() as cursor:
            cursor.execute(get_config_tbl_data_sql)
            number_of_attempts = cursor.fetchone()
    except Exception as error:
        err, = error.args
        err_message = f'Error code : {err.code}, messsage : {err.message}'
        LOGGER.error(err_message)

    if number_of_attempts is None:
        attempt_count = 0
    else:
        attempt_count = number_of_attempts[0]

    return attempt_count


def get_status_log_entry(config, monitor_status):
    """
    Get files to be monitored from FILE_MONITOR_CONFIG table.

    Logic to load the files to be monitored.
    1. Get records from FILE_MONITOR_CONFIG.
    2. Validate empty or NULL fields and replace with default values.
    3. Validate cutoff time. It should be in HH24:MM:SS if not send notification and quit the program
    4. Based on the FILE_MONITOR_CONFIG.FILE_DATE_QUALIFIER value, replace the date placeholder on the filename.
        a. If FILE_MONITOR_CONFIG.FILE_DATE_QUALIFIER value not found in VALID_FILE_DATE_QUALIFIER, send
           notification and quit the program

    Args:
        config (file_config) : File Config object

    Returns:
        status_log_map (Map) : Status log entry

    Raises:
        None
        :param s:
        :param config:
    """
    status_log_sql = f"""
                        select *
                        from {STATUS_LOG_TABLE} 
                        where
                            EVENT_DATE = TO_DATE(:v_run_date,'YYYYMMDD')
                            AND FILE_GROUP = '{config.file_group}'
                            AND FILE_NAME = '{config.file_name}'
                            AND MONITOR_STATUS = '{monitor_status}'
                    """

    LOGGER.debug(f"Executing {status_log_sql}")
    LOGGER.debug(f"Parameters: {[BUILD_OBJ.today]}")

    try:
        csr = DB_CONNECTION.cursor()
        csr.execute(status_log_sql, [BUILD_OBJ.today])
        result = csr.fetchall()
    except BaseException as be:
        LOGGER.fatal(be)
        abend_pgm(f"Exception encountered attempting to fetch data from table {STATUS_LOG_TABLE}")
    finally:
        csr.close()

    return result


def get_config_tbl_count():
    """
    Get file monitoring configuration table data.

    Get files to be monitored with other configuration information

    Args:
        None

    Returns:
        None

    Raises:
        None
    """
    record_count = 0
    get_config_tbl_count_sql = f"""SELECT COUNT(1) FROM {CONFIG_TABLE} 
                                where (trim(MONITOR_ENABLED_IND) = 'Y' or trim(MONITOR_ENABLED_IND) = 'y')"""

    if FILE_GROUP is not None:
        get_config_tbl_count_sql += f"  AND FILE_GROUP = '{FILE_GROUP}'"

    LOGGER.debug(f"Executing {get_config_tbl_count_sql}")

    try:
        with DB_CONNECTION.cursor() as cursor:
            cursor.execute(get_config_tbl_count_sql)
            record_count = cursor.fetchone()
    except Exception as error:
        err, = error.args
        err_message = f'Error code : {err.code}, messsage : {err.message}'
        LOGGER.error(err_message)

    LOGGER.debug(f"Found {record_count[0]} entries.")

    return record_count[0]


def check_config_tbl_has_data():
    config_tbl_record_count = get_config_tbl_count()
    if config_tbl_record_count == 0:
        event_code = "FAILED"
        if DEFAULT_NOTIFY_THROUGH_DSLOG is not None and DEFAULT_NOTIFY_THROUGH_DSLOG.upper() == 'Y':
            log_level = "ERROR"
        else:
            log_level = "INFO"
        if FILE_GROUP is not None:
            log_message = (f"For the file group {FILE_GROUP}, no record found in '{BUILD_OBJ.user_id}.{CONFIG_TABLE}' "
                           f"table or MONITOR_ENABLED_IND column is set to other than 'Y' or 'y' for all records.")
        else:
            log_message = (f"No record found in '{BUILD_OBJ.user_id}.{CONFIG_TABLE}' table or "
                           f"MONITOR_ENABLED_IND column is set to other than 'Y' or 'y' for all records.")

        LOGGER.error(f"{log_message}")

        file_config = FileConfig()
        file_config.file_group = "Application"
        file_config.final_folder_name = "N/A"
        file_config.file_name = PGM
        file_config.actual_filename = "N/A"

        # Update status and DS_LOG. If status and DS_LOG are already updated, don't enter again
        records = get_status_log_entry(file_config, "CONFIG FAILED")
        if len(records) == 0:
            # update DS_LOG
            BUILD_OBJ.log_monitoring(event_code, log_message, log_level)

            # Update Status log
            update_status_log(file_config, "CONFIG FAILED", log_message)
        else:
            LOGGER.info(f"{STATUS_LOG_TABLE} and DS_LOG table were already updated")

        BUILD_OBJ.log_monitoring("COMPLETE", "Finished Processing", 'INFO')
        LOGGER.info(f"Exiting the application")
        sys.exit(0)


def main():
    """
    Program entry method.
    1. Gets the command line options
    2. Gets files to be monitored from DSMONITOR_PROD.FILE_MONITOR_CONFIG table
    3. Process each file
        a. If processed, add an entry with 'SUCCESS' to DSMONITOR_PROD.FILE_MONITOR_STATUS_LOG table
        b. If failed, send an notification through email and/or DSLOG. Add an entry with 'FAILED' to
            DSMONITOR_PROD.FILE_MONITOR_STATUS_LOG table
        c. If file not processed ot received, try max number of failed attempts and send an notification
            through email and/or DSLOG. Add an entry with 'MONITOR FAILED' to DSMONITOR_PROD.FILE_MONITOR_STATUS_LOG
            table
    :param None
    :return: 0
    """
    global LOGGER
    global BUILD_OBJ
    global DB_CONNECTION
    global PGM

    PGM = os.path.basename(sys.argv[0])

    # process command ine options
    get_opts()

    # Instantiate the build object with log level
    BUILD_OBJ = Build(
        script_name='FILE_MONITOR',
        script_filename=PGM,
        app_id='FILE_MONITOR',
        log_level=command_line_debug)

    # Get the logger object
    LOGGER = BUILD_OBJ.get_logger()

    # Make an entry to DSLOG
    BUILD_OBJ.log_monitoring("START", "Starting", 'INFO')

    LOGGER.info("Program starting")

    # Read configuration items from build config for tables, email, etc.
    get_config()

    # Establish database connection.
    DB_CONNECTION = BUILD_OBJ.get_dbconnection('dsmonitor')

    # Check configure table has data. If no data add entry to DS_LOG and exit the application
    check_config_tbl_has_data()

    # Get File Config information
    file_config_map = {}
    get_file_config_data(file_config_map)

    # Perform monitoring.
    event_code = "COMPLETE"
    log_level = "INFO"
    log_message = f"File Monitor finished processing {len(file_config_map)} files"

    if len(file_config_map):
        # process monitoring
        run_monitoring(file_config_map)
    else:
        log_message = f"All the records from {CONFIG_TABLE} table has been processed for {BUILD_OBJ.today}."
        LOGGER.info(log_message)

    BUILD_OBJ.log_monitoring(event_code, log_message, log_level)


# =-=-=-=-=-=-=-=-=-=-=--=-=-=-=-=- begin main -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
if __name__ == '__main__':
    main()
