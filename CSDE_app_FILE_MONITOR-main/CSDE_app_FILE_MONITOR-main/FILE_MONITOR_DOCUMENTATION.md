# File Monitor System - Complete Flow Documentation

## System Overview
The File Monitor system is a Python-based application that monitors file arrivals in designated directories, validates them, and logs their status. It integrates with Oracle database for configuration and status tracking, and sends notifications via email.

---

## 1. HIGH-LEVEL FLOW

```
┌─────────────────────────────────────────────────────────────────┐
│         FILE MONITOR SYSTEM - HIGH LEVEL FLOW                   │
└─────────────────────────────────────────────────────────────────┘

START
  │
  ├─► INITIALIZE BUILD ENVIRONMENT
  │   ├─ Load System Info (User, Hostname, PID)
  │   ├─ Setup Logger
  │   └─ Load Configuration from XML
  │
  ├─► ESTABLISH DATABASE CONNECTION
  │   └─ Connect to 'dsmonitor' database
  │
  ├─► LOAD FILE MONITORING CONFIG
  │   ├─ Fetch enabled records from FILE_MONITOR_CONFIG table
  │   ├─ Group by FILE_GROUP
  │   └─ Validate configuration parameters
  │
  ├─► RUN FILE MONITORING
  │   ├─ For each file group:
  │   │  ├─ Get current time
  │   │  ├─ For each configured file:
  │   │  │  ├─ Determine expected filename (with date replacement)
  │   │  │  ├─ Check if file exists
  │   │  │  ├─ Check file timestamp vs cutoff time
  │   │  │  ├─ Validate file content (if custom validation enabled)
  │   │  │  ├─ Update status log (SUCCESS/FAILED/MONITOR_FAILED)
  │   │  │  └─ Send notifications (email/dslog)
  │   │  └─ Process next file
  │   └─ Process next file group
  │
  ├─► LOG COMPLETION
  │   ├─ Insert completion record to DS_LOG
  │   └─ Send completion notification (if configured)
  │
  ├─► CLOSE DATABASE CONNECTION
  │
  └─► END

SUCCESS: All files processed with status logged
FAILURE: Exception handled, logs sent, application exits gracefully
```

---

## 2. DETAILED STEP-BY-STEP FLOW

### Phase 1: Application Initialization

**Step 1.1: Parse Command Line Arguments**
- Input: Command line parameters
- Process:
  - Check for `--file-group` or `-g` flag (optional - single file group)
  - Check for `--debug` or `-d` flag (optional - DEBUG logging level)
  - Check for `--help` or `-h` flag (display help)
- Output: FILE_GROUP, command_line_debug level set in globals
- Error Handling: Invalid parameters → Display usage and exit

**Step 1.2: Instantiate Build Object**
- Input: script_name='FILE_MONITOR', log_level from command line
- Process:
  - Call Build.__init__() constructor
  - Trigger Build.initialize() method
- Output: BUILD_OBJ with all environment initialized

**Step 1.3: Build.initialize() Execution**
- Process:
  1. Set script filename (from sys.argv[0])
  2. Get current date using get_date('today')
  3. Capture system info:
     - current_username = getpass.getuser()
     - current_working_dir = os.getcwd()
     - hostname = socket.gethostname()
     - pid = os.getpid()
     - env_name = os.environ.get('ENV_NAME')
     - app_name = os.environ.get('APP_NAME')
     - smtp_server = os.environ.get('DEFAULT_SMTP_SERVER')
  4. Set configuration file path:
     - Windows: C:\Users\...\build_config.xml
     - Unix: /ds/env/{ENV_NAME}/{APP_NAME}/common/etc/build_config.xml
  5. Call init_logger() to setup logging
  6. Call load_configuration() to load XML config
- Output: BUILD_OBJ fully initialized with logger and config

**Step 1.4: Initialize Logger**
- Input: log_level from command line ('INFO' or 'DEBUG')
- Process:
  1. Create logger instance using logging.getLogger()
  2. Set log level based on input
  3. Create formatter with format:
     ```
     "%(asctime)s.%(msecs)03d [%(filename)s-%(lineno)d] (%(levelname)s) 
     <%(hostname)s.%(process)s> - %(message)s"
     ```
  4. Create StreamHandler pointing to stdout
  5. Add HostnameFilter to append hostname to log records
  6. Attach handler to logger
- Output: Logger ready for use

**Step 1.5: Load Configuration from XML**
- Input: absolute_config_filename (build_config.xml path)
- Process:
  1. Open and read build_config.xml file
  2. Parse XML using lxml.objectify.fromstring()
  3. Store parsed config in BUILD_OBJ.config
- Output: BUILD_OBJ.config object with all XML configuration
- Error Handling: File not found or parse error → Raise exception

### Phase 2: Configuration Loading

**Step 2.1: Get Configuration (get_config())**
- Process: Load default parameters from build_config.xml into globals:
  
  | Parameter | Default Value | Purpose |
  |-----------|---------------|---------|
  | DEFAULT_EMAIL_NOTIFICATION_ADDRESS | 'Y' | Send email notifications? |
  | INBOUND_DEFAULT_PROCESSED_FOLDER | '.processed' | Where to move processed inbound files |
  | INBOUND_DEFAULT_FAILED_FOLDER | '.failed' | Where to move failed inbound files |
  | OUTBOUND_DEFAULT_PROCESSED_FOLDER | '.processed' | Where to move processed outbound files |
  | OUTBOUND_DEFAULT_FAILED_FOLDER | '.failed' | Where to move failed outbound files |
  | NUMBER_OF_FAILED_ATTEMPTS | 3 | Max retries before giving up |
  | DEFAULT_CUTOFF_TIME | '03:00:00' | Default cutoff time for file arrival |
  | CONFIG_TABLE | 'FILE_MONITOR_CONFIG' | Table with file monitoring configs |
  | ATTEMPT_STATUS_TABLE | (from XML) | Table tracking attempt counts |
  | STATUS_LOG_TABLE | (from XML) | Table logging file status |
  | DEFAULT_NOTIFY_THROUGH_EMAIL | (from XML) | Email notifications enabled? |
  | DEFAULT_NOTIFY_THROUGH_DSLOG | (from XML) | DS_LOG notifications enabled? |

**Step 2.2: Establish Database Connection**
- Input: 'dsmonitor' connection name
- Process:
  1. Call BUILD_OBJ.get_dbconnection('dsmonitor')
  2. In Build class:
     - Get connection node from config using get_connection_data('dsmonitor')
     - Extract: db_node, sid, schema, user_id, password
     - Create cx_Oracle connection string
     - Open connection using cx_Oracle.connect()
- Output: DB_CONNECTION object (global)
- Error Handling: Connection failure → Log error and exit

**Step 2.3: Check Configuration Table Has Data**
- Input: CONFIG_TABLE name, optional FILE_GROUP
- Process:
  1. Build SQL: `SELECT COUNT(1) FROM {CONFIG_TABLE} WHERE MONITOR_ENABLED_IND = 'Y'`
  2. If FILE_GROUP specified, add: `AND FILE_GROUP = '{FILE_GROUP}'`
  3. Execute query
  4. If count = 0:
     - Log error message
     - Create dummy FileConfig object for logging
     - Check if already logged in STATUS_LOG_TABLE
     - If not logged, insert to STATUS_LOG_TABLE and DS_LOG
     - Exit application with success code
- Output: Either continue or exit
- Error Handling: SQL execution error → Log and exit

**Step 2.4: Load File Configuration Data**
- Input: None
- Process:
  1. Execute: `SELECT * FROM {CONFIG_TABLE} WHERE MONITOR_ENABLED_IND = 'Y'`
  2. For each result row:
     - Create FileConfig object
     - Populate with row data:
       - file_group
       - process
       - process_description
       - file_name
       - file_date_qualifier
       - file_cutoff_time
       - file_type
       - file_inbound_folder / file_outbound_folder
       - number_of_failed_attempt
       - notify_through_email
       - failure_email
       - notify_through_dslog
       - custom_validation_script
       - custom_notification_message
       - entry_date
       - entered_by
     - Validate cutoff_time format (HH24:MM:SS)
     - Validate file_date_qualifier against VALID_FILE_DATE_QUALIFIER list
     - If validation fails → Send notification and abort
     - Group by file_group in file_config_map dictionary
- Output: file_config_map = { 'GROUP1': [FileConfig1, FileConfig2, ...], 'GROUP2': [...] }
- Error Handling: Invalid configuration → Send notification, update status, exit

### Phase 3: File Monitoring Execution

**Step 3.1: Run Monitoring (run_monitoring())**
- Input: file_config_map (grouped file configurations)
- Process:
  1. Get current system time: `datetime.now().time()`
  2. If FILE_GROUP command line arg specified:
     - Call process_file_monitoring(file_config_map[FILE_GROUP], current_time)
  3. Else:
     - For each file_group_key in file_config_map:
       - Log: "Processing File Group '{file_group_key}'"
       - Call process_file_monitoring(file_config_list, current_time)
- Output: All files processed
- Error Handling: Exceptions caught in process_file_monitoring

**Step 3.2: Process File Monitoring (process_file_monitoring())**
- Input: file_config_list (list of FileConfig objects), current_time
- Process:
  1. For each FileConfig in file_config_list:
     - Call monitor_single_file(config, current_time)
  2. Aggregate results
- Output: All files in group processed

**Step 3.3: Monitor Single File (monitor_single_file())**
- Input: FileConfig object, current_time
- Process:

  **3.3.1: Replace Date Qualifier in Filename**
  - Get file_date_qualifier from config
  - If qualifier = 'today' → Use current date (YYYYMMDD format)
  - If qualifier = 'yesterday' → Use previous date
  - If qualifier = 'last_month' → Use last month (YYYYMM format)
  - If qualifier = 'this_month' → Use current month (YYYYMM)
  - etc. (10 different date qualifier options supported)
  - Replace {date} placeholder in file_name with actual date
  - Output: actual_filename
  
  **3.3.2: Determine Expected File Path**
  - Get inbound_folder or outbound_folder from config
  - Combine with actual_filename
  - Use default folder if not specified in config
  - Output: full_file_path
  
  **3.3.3: Check If File Exists**
  - Use pathlib.Path.exists() or os.path.isfile()
  - If file NOT found:
     - Get current failed attempt count from ATTEMPT_STATUS_TABLE
     - If attempt_count < NUMBER_OF_FAILED_ATTEMPTS:
       - Increment attempt count in ATTEMPT_STATUS_TABLE
       - Insert "MONITOR FAILED" record in STATUS_LOG_TABLE
       - Continue to next file
     - If attempt_count >= NUMBER_OF_FAILED_ATTEMPTS:
       - Send notification: "File not received after {N} attempts"
       - Update STATUS_LOG_TABLE with final "MONITOR FAILED"
       - Reset attempt count
       - Continue to next file
  - If file found:
     - Continue to Step 3.3.4
  
  **3.3.4: Check File Timestamp vs Cutoff Time**
  - Get file modification time: os.path.getmtime(file_path)
  - Get cutoff_time from config (or use DEFAULT_CUTOFF_TIME if not specified)
  - Get yesterday's date (since files typically arrive for previous day)
  - Create cutoff datetime: yesterday + cutoff_time
  - If file mtime < cutoff datetime:
     - File arrived before cutoff → Proceed to validation
  - If file mtime >= cutoff datetime:
     - File arrived after cutoff → Log warning, mark as "NOT PROCESSED"
     - Update STATUS_LOG_TABLE
     - Continue to next file
  
  **3.3.5: Validate File (Optional Custom Validation)**
  - If custom_validation_script specified in config:
     - Execute custom validation script (subprocess call)
     - Pass file path as parameter
     - If validation returns success (exit code 0):
       - Mark file as VALIDATED
       - Continue to Step 3.3.6
     - If validation fails (non-zero exit code):
       - Log validation error
       - Send notification with failure reason
       - Update STATUS_LOG_TABLE with "VALIDATION FAILED"
       - Continue to next file
  - If no custom validation:
     - File automatically considered valid
     - Continue to Step 3.3.6
  
  **3.3.6: Move File to Processed Folder**
  - Get processed_folder from config (or use default)
  - Move file from source folder to processed folder
  - If move fails:
     - Log error
     - Send notification
     - Update STATUS_LOG_TABLE with "MOVE FAILED"
     - Continue to next file
  - If move succeeds:
     - Continue to Step 3.3.7
  
  **3.3.7: Update Status and Send Notifications**
  - Update STATUS_LOG_TABLE:
     - INSERT into FILE_MONITOR_STATUS_LOG
     - Columns: EVENT_DATE, FILE_GROUP, FILE_NAME, MONITOR_STATUS, MESSAGE, PROCESSED_TIMESTAMP
     - MONITOR_STATUS = 'SUCCESS' or 'FAILED' or other
  - Check if email notification needed:
     - If notify_through_email = 'Y' and status = 'SUCCESS':
       - Send email with success message
     - If notify_through_email = 'Y' and status = 'FAILED':
       - Send email with failure_email address
  - Check if DS_LOG notification needed:
     - If notify_through_dslog = 'Y':
       - Call BUILD_OBJ.log_monitoring() to insert to DS_LOG table
  - Log to application logger

### Phase 4: Completion

**Step 4.1: Log Monitoring Completion**
- Input: event_code='COMPLETE', message, log_level='INFO'
- Process:
  1. Call BUILD_OBJ.log_monitoring(event_code, message, log_level)
  2. In Build class:
     - Build INSERT SQL:
       ```sql
       INSERT INTO DS_LOG (
         EVENT_ID, EVENT_CODE, EVENT_DATE, PROCESS, 
         MESSAGE, RUN_DATE, HOSTNAME, USER_ID, PID, LOG_LEVEL
       ) VALUES (
         SEQ_DS_EVENT_ID.NEXTVAL, :event_code, SYSDATE, :process,
         :message, :run_date, :hostname, :user_id, :pid, :log_level
       )
       ```
     - Get email configuration from DS_APP_CONFIG and DS_PROCESS_CONFIG tables
     - Execute INSERT
     - COMMIT transaction
     - If event_code='SUCCESS' and email configured:
       - Call send_html_email()
     - If event_code='FAILED' and email configured:
       - Call send_html_email()
  3. Return

**Step 4.2: Send Email Notification**
- Input: event_code, to_email_address, message
- Process:
  1. Build HTML email message with:
     - Subject line based on event_code
     - Event details (timestamp, hostname, process, message)
  2. Create MIME multipart message
  3. Connect to SMTP server (smtp_server from config)
  4. Send email with SSL
  5. Close connection
  6. Log success/failure

**Step 4.3: Close Database Connection**
- Input: DB_CONNECTION
- Process:
  1. COMMIT any pending transactions
  2. Close cursor if open
  3. Close connection
- Output: Connection closed

**Step 4.4: Exit Application**
- Process:
  1. Call end_pgm() with completion message
  2. Close remaining resources
  3. Log final message
  4. sys.exit(0) - success code

### Phase 5: Error Handling

**If Exception Occurs:**
1. Call abend_pgm(error_message)
2. ROLLBACK database transaction
3. Log error to LOGGER
4. Insert error record to DS_LOG table with event_code='FAILED'
5. Send error notification email (if configured)
6. Close all connections
7. sys.exit() with error

---

## 3. DATA FLOW DIAGRAM

```
INPUT SOURCES:
  1. Command Line Arguments (--file-group, --debug, --help)
  2. Environment Variables (ENV_NAME, APP_NAME, DEFAULT_SMTP_SERVER)
  3. Configuration File (build_config.xml)
  4. Database Tables:
     - FILE_MONITOR_CONFIG (file configurations)
     - FILE_MONITOR_ATTEMPT_STATUS (retry counts)
     - FILE_MONITOR_STATUS_LOG (status tracking)
     - DS_LOG (event logging)
     - DS_APP_CONFIG (email config)
     - DS_PROCESS_CONFIG (process email config)
  5. File System (monitored directories)

PROCESSING:
  Build Object (initialization, logging, DB access, email)
    ↓
  FileConfig Objects (configuration containers)
    ↓
  File Monitoring Logic (validation, status tracking)
    ↓
  Database Updates (status log, attempt count, DS_LOG)
    ↓
  Email Notifications (SMTP)

OUTPUT:
  1. Console Logs (DEBUG/INFO level)
  2. Database Updates:
     - FILE_MONITOR_STATUS_LOG (file status)
     - DS_LOG (event tracking)
     - FILE_MONITOR_ATTEMPT_STATUS (retry counter)
  3. Email Notifications (success/failure)
  4. File Movement (source → processed/failed folder)
  5. Exit Code (0 = success, 1 = failure)
```

---

## 4. KEY CLASSES AND RESPONSIBILITIES

### FileConfig Class
```python
@auto_str decorator adds automatic __str__ representation
Holds: file_group, process, file_name, file_date_qualifier, file_cutoff_time,
       file_type, inbound/outbound folders, notification settings,
       custom validation script, etc.
```

### Build Class
```python
Responsibilities:
  1. System environment initialization (user, hostname, PID, etc.)
  2. Logger setup and management
  3. Configuration file loading and parsing (XML)
  4. Database connection management
  5. Event logging to DS_LOG table
  6. Email notification sending
  7. Date/time utilities (get_date, date conversions)
  
Key Methods:
  - __init__(script_name, script_filename, app_id, log_level)
  - initialize()
  - init_logger(log_level)
  - load_configuration()
  - get_config(config_name, sql_safe=True)
  - get_dbconnection(connection_name)
  - log_monitoring(event_code, message, log_level)
  - send_html_email(event_code, to_email_address, message)
  - get_date(date_type, delta_days) - static
```

### file_monitor.py Module
```python
Global Variables:
  - PGM: Program name
  - LOGGER: Logger instance
  - DB_CONNECTION: Database connection
  - BUILD_OBJ: Build object instance
  - Configuration globals (table names, defaults, etc.)
  - FILE_GROUP: Command line specified file group (optional)
  
Main Functions:
  - main(): Program entry point
  - get_opts(): Parse command line arguments
  - get_config(): Load defaults from build_config.xml
  - check_config_tbl_has_data(): Validate configuration table
  - get_file_config_data(file_config_map): Load file configs
  - run_monitoring(file_config_map): Execute monitoring
  - process_file_monitoring(file_config_list, current_time): Process group
  - monitor_single_file(config, current_time): Monitor one file
  - get_status_log_entry(config, monitor_status): Query status
  - abend_pgm(message): Error exit handler
  - end_pgm(message): Normal exit handler
```

---

## 5. DATABASE SCHEMA (Key Tables)

### FILE_MONITOR_CONFIG
```
FILE_GROUP                          VARCHAR2(50)
PROCESS                             VARCHAR2(100)
PROCESS_DESCRIPTION                 VARCHAR2(255)
FILE_NAME                           VARCHAR2(255)    [Can contain {date} placeholder]
FILE_DATE_QUALIFIER                 VARCHAR2(30)     [today, yesterday, last_month, etc.]
FILE_CUTOFF_TIME                    VARCHAR2(8)      [HH24:MM:SS format]
FILE_TYPE                           VARCHAR2(20)     [INBOUND or OUTBOUND]
FILE_INBOUND_FOLDER                 VARCHAR2(255)
FILE_INBOUND_PROCESSED_FOLDER       VARCHAR2(255)
FILE_INBOUND_FAILED_FOLDER          VARCHAR2(255)
FILE_OUTBOUND_FOLDER                VARCHAR2(255)
FILE_OUTBOUND_PROCESSED_FOLDER      VARCHAR2(255)
FILE_OUTBOUND_FAILED_FOLDER         VARCHAR2(255)
NUMBER_OF_FAILED_ATTEMPT            NUMBER
NOTIFY_THROUGH_EMAIL                VARCHAR2(1)      [Y or N]
FAILURE_EMAIL                       VARCHAR2(255)
NOTIFY_THROUGH_DSLOG                VARCHAR2(1)      [Y or N]
CUSTOM_VALIDATION_SCRIPT            VARCHAR2(255)    [Path to validation script]
CUSTOM_NOTIFICATION_MESSAGE         VARCHAR2(255)
MONITOR_ENABLED_IND                 VARCHAR2(1)      [Y or N - must be Y to monitor]
ENTRY_DATE                          DATE
ENTERED_BY                          VARCHAR2(50)
```

### FILE_MONITOR_STATUS_LOG
```
STATUS_LOG_ID                       NUMBER (PK)
FILE_GROUP                          VARCHAR2(50)
FILE_NAME                           VARCHAR2(255)
EVENT_DATE                          DATE
MONITOR_STATUS                      VARCHAR2(30)     [SUCCESS, FAILED, MONITOR FAILED, etc.]
MESSAGE                             VARCHAR2(1000)
PROCESSED_TIMESTAMP                 TIMESTAMP
ATTEMPT_COUNT                       NUMBER
```

### DS_LOG
```
EVENT_ID                            NUMBER (PK, from sequence)
EVENT_CODE                          VARCHAR2(30)     [SUCCESS, FAILED, START, COMPLETE, etc.]
EVENT_DATE                          DATE
PROCESS                             VARCHAR2(100)
MESSAGE                             VARCHAR2(4000)
RUN_DATE                            VARCHAR2(8)      [YYYYMMDD format]
HOSTNAME                            VARCHAR2(100)
USER_ID                             VARCHAR2(50)
PID                                 NUMBER
LOG_LEVEL                           VARCHAR2(10)     [INFO, DEBUG, ERROR, FATAL]
```

---

## 6. CONFIGURATION FILE (build_config.xml)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <dbconnections>
    <dbconnection name="dsmonitor">
      <node>db_hostname_or_tnsname</node>
      <sid>database_sid</sid>
      <schema>schema_name</schema>
      <user_id>username</user_id>
      <password>password</password>
    </dbconnection>
  </dbconnections>
  
  <default_email_notification_address>Y</default_email_notification_address>
  <inbound_default_processed_folder>.processed</inbound_default_processed_folder>
  <inbound_default_failed_folder>.failed</inbound_default_failed_folder>
  <outbound_default_processed_folder>.processed</outbound_default_processed_folder>
  <outbound_default_failed_folder>.failed</outbound_default_failed_folder>
  <number_of_failure_attempts>3</number_of_failure_attempts>
  <default_cutoff_time>03:00:00</default_cutoff_time>
  <db_file_monitor_config_tbl>FILE_MONITOR_CONFIG</db_file_monitor_config_tbl>
  <db_file_monitor_attempt_status_tbl>FILE_MONITOR_ATTEMPT_STATUS</db_file_monitor_attempt_status_tbl>
  <db_file_monitor_status_log_tbl>FILE_MONITOR_STATUS_LOG</db_file_monitor_status_log_tbl>
  <ds_log_table>DS_LOG</ds_log_table>
  <ds_app_config_table>DS_APP_CONFIG</ds_app_config_table>
  <ds_process_config_table>DS_PROCESS_CONFIG</ds_process_config_table>
</configuration>
```

---

## 7. VALID PARAMETERS AND VALUES

### File Date Qualifier Options
```
'today'               → Current date (YYYYMMDD)
'yesterday'           → Previous day (YYYYMMDD)
'tomorrow'            → Next day (YYYYMMDD)
'days_ago'            → N days ago (requires delta_days param)
'days_from_now'       → N days in future (requires delta_days param)
'last_month_begin'    → First day of last month
'last_month_end'      → Last day of last month
'last_month'          → Last month in YYYYMM format
'this_month'          → Current month in YYYYMM format
'next_month'          → Next month in YYYYMM format
```

### Log Levels
```
'DEBUG'    → Verbose output for troubleshooting
'INFO'     → Standard operational logging
'ERROR'    → Error conditions
'FATAL'    → Critical failures
```

### Event Codes (DS_LOG)
```
'START'        → Application started
'SUCCESS'      → File processed successfully
'FAILED'       → File processing failed
'COMPLETE'     → Application completed
'CONFIG FAILED' → Configuration error
```

### Monitor Status Values
```
'SUCCESS'         → File found, validated, processed
'FAILED'          → File validation failed
'MONITOR FAILED'  → File not received after N attempts
'NOT PROCESSED'   → File arrived after cutoff time
'VALIDATION FAILED' → Custom validation script failed
'MOVE FAILED'     → Failed to move file to processed folder
```

---

## 8. ERROR SCENARIOS AND HANDLING

| Scenario | Detection | Action | Notification |
|----------|-----------|--------|--------------|
| Config file missing | File open fails | Log error, raise exception | Email to default address |
| DB connection fails | cx_Oracle error | Rollback, close, log error | Email to default address |
| No config records | COUNT(*) = 0 | Log to STATUS_LOG, exit gracefully | Email if configured |
| Invalid cutoff time | Format validation | Send notification, abort | Email + DS_LOG |
| Invalid date qualifier | Not in VALID list | Send notification, abort | Email + DS_LOG |
| File not found | os.path.exists() fails | Increment attempt count | Email if max attempts exceeded |
| File after cutoff | mtime >= cutoff_datetime | Mark as NOT_PROCESSED | Email if configured |
| Validation fails | Custom script exit code ≠ 0 | Mark as VALIDATION_FAILED | Email if configured |
| Move operation fails | os.rename() exception | Mark as MOVE_FAILED | Email if configured |
| Email send fails | SMTP connection error | Log error, continue | Log message only |
| DB commit fails | SQL execute error | Rollback, log error | Email to default address |

---

## 9. EXECUTION EXAMPLES

### Example 1: Monitor Single File Group (SSRX_PC)
```bash
python file_monitor.py --file-group SSRX_PC --debug
```
- Only processes files in SSRX_PC group
- Sets log level to DEBUG
- All other groups are skipped

### Example 2: Monitor All Configured Groups (Default)
```bash
python file_monitor.py
```
- Processes all file groups in FILE_MONITOR_CONFIG
- Uses INFO log level
- No file group restriction

### Example 3: Monitor with Custom Log Level
```bash
python file_monitor.py --file-group CLAIMS --debug
```
- Monitors CLAIMS group
- Detailed DEBUG output

### Example 4: Display Help
```bash
python file_monitor.py --help
```
- Shows usage information
- Exits without processing

---

## 10. SYSTEM INTEGRATION POINTS

```
INPUT INTEGRATIONS:
  ├─ Command Line (getopt)
  ├─ Environment Variables
  ├─ XML Configuration File
  ├─ Oracle Database (cx_Oracle)
  ├─ File System (pathlib, os)
  └─ System Info (socket, getpass, platform)

OUTPUT INTEGRATIONS:
  ├─ Console Logging (logging module)
  ├─ Oracle Database (INSERT, UPDATE)
  ├─ Email (smtplib)
  └─ File System (move operations)

DEPENDENCIES:
  ├─ Python Libraries: pathlib, datetime, logging, getopt, os, sys, re
  ├─ External: cx_Oracle, lxml
  ├─ Database: Oracle 11g+ with DS_LOG tables
  └─ Infrastructure: SMTP server, Oracle listener, Network access
```

---

## END OF DOCUMENTATION
