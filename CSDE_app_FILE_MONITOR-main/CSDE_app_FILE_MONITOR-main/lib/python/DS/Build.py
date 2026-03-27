import logging
import smtplib
import ssl
import time
import zlib
from base64 import urlsafe_b64encode as b64e, urlsafe_b64decode as b64d
from datetime import date, datetime, timedelta
from calendar import monthrange
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import getpass
import re
import os
import platform
import socket
import sys

# Script file name
import cx_Oracle
from lxml import objectify


class Build:
    script_filename = None

    # Current date
    today = None

    # Executing user name
    current_username = None

    # Current working directory
    current_working_dir = None

    # Host name
    hostname = None

    # Application PID
    pid = None

    # Application environment
    env_name = None

    # Application name
    app_name = None

    # DS Monitor APP_ID
    app_id = None

    # SMTP Hostname
    smtp_server = None

    # Absolute configuration file path
    win_base_dir = None
    absolute_config_filename = None
    absolute_output_filename = None

    # Configuration object holds application configuration
    config = None

    # Logger
    logger = None

    # application db connection
    app_dbConnection = None

    # Command line debug option
    command_line_debug = None

    # Log level
    log_level = None

    # Default email
    default_email = 'Data.Services@RelayHealth.com'

    # Success email
    success_email = None

    # Failure email
    failure_email = None

    # Script name must be passed in
    script_name = None

    # main DB Connection info
    db_node = None
    sid = None
    serial = None
    instance_id = None
    user_id = None
    real_schema = None

    def __init__(self):
        """
        Default constructor
        """
        self.initialize()

    def __init__(self, script_name, script_filename, app_id, log_level='INFO'):
        """
        Overloaded constructor

        :param script_name: name of calling script (e.g.: MCS_PATIENT_LOAD)
        :param log_level: 'INFO','DEBUG'
        """
        self.script_name = script_name
        self.script_filename = script_filename
        self.log_level = log_level
        self.app_id = app_id
        self.initialize()

    def initialize(self):

        # Set Script filename
        if not self.script_filename:
            self.script_filename = os.path.basename(__file__)

        # Current date
        self.today = self.get_date("today")

        # Executing user name
        self.current_username = getpass.getuser()

        # Current working directory
        self.current_working_dir = os.getcwd()

        # Host name
        self.hostname = socket.gethostname()

        # Application PID
        self.pid = os.getpid()

        # Application environment
        self.env_name = os.environ.get('ENV_NAME')

        # Application name
        self.app_name = os.environ.get('APP_NAME')

        # SMTP Hostname
        self.smtp_server = os.environ.get('DEFAULT_SMTP_SERVER')

        # Absolute configuration file path
        self.win_base_dir = "C:\\Users\\e5yjvke\\OneDrive - McKesson Corporation\\MK-Data\\Development" \
                            "\\ds\\env\\dev\\FileMonitor\\common\\etc\\"
        # self.win_base_dir = "C:\\DataServices\\Denial Conversion\\PyCharm\\"
        self.absolute_config_filename = None
        if platform.system() == 'Windows':
            self.absolute_config_filename = f'{self.win_base_dir}{os.sep}build_config.xml'
        else:
            self.absolute_config_filename = f'{os.sep}ds{os.sep}env{os.sep}{self.env_name}{os.sep}{self.app_name}' \
                                            f'{os.sep}common{os.sep}etc{os.sep}build_config.xml'

        # Initialize Logger
        if not self.log_level:
            self.log_level = 'INFO'

        self.init_logger(self.log_level)

        self.load_configuration()

    def get_logger(self):
        """
        Returns an instance of console logger

        :return: logger instance
        """
        if not self.log_level:
            self.log_level = 'INFO'

        if not self.logger:
            self.init_logger(self.log_level)

        return self.logger

    def load_configuration(self):
        """
        Load 'build_config.xml' application configuration file.
        Failure to load the configuration file is reported as ERROR in log file.
        A failure record is NOT created in DS_LOG file

        :return: None
        """

        self.logger.info(f'loading configuration file : [{self.absolute_config_filename}]')
        try:
            with open(self.absolute_config_filename) as f:
                xml = f.read()
            self.config = objectify.fromstring(xml)
            self.logger.debug("Configuration file loaded successfully")
        except Exception as ex:
            raise ex

    def get_config(self, config_name, sql_safe=True):
        ret_val = None
        if self.config is None or len(self.config) == 0:
            raise BaseException("get_config(): Configuration file not yet loaded")
        try:
            ret_val = eval(f"self.config.{config_name}.text")
        except BaseException as be:
            return None

        if sql_safe and ret_val:
            match = re.match(r".*(\'|\")+.*", ret_val)
            if match:
                raise BaseException(
                    f"get_config(): (SQL_SAFE) Invalid character \' or \" found in configuration ({config_name})")
        return ret_val

    def init_logger(self, log_level_in="DEBUG"):
        """
        Setup a console logger.

        :return: None
        """

        self.logger = logging.getLogger()
        if log_level_in is not None:
            self.log_level = log_level_in
        self.logger.setLevel(getattr(logging, self.log_level))
        log_formatter = logging.Formatter(
            fmt="%(asctime)s.%(msecs)03d [%(filename)s-%(lineno)d] (%(levelname)s) <%(hostname)s.%(process)s> - %("
                "message)s",
            datefmt='%H:%M:%S')
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(log_formatter)
        console_handler.addFilter(HostnameFilter())
        self.logger.addHandler(console_handler)
        self.logger.debug(f'Logger initialized successfully. Log level set to [{self.log_level}]')

    def get_connection_data(self, name):
        """
        For the given name, get the database connection information from configuration file.
        :param name: Database connection name
        :return: Database connection node
        """
        connection_node = None
        for connection in self.config.database.connection:
            if name == connection.attrib['name']:
                connection_node = connection
                break
        return connection_node

    @staticmethod
    def encrypt(data):
        """
        Encrypt password string
        :param data: plain password
        :return: encrypted password
        """
        return b64e(zlib.compress(data, 9))

    @staticmethod
    def decrypt(data):
        """
        Decrypt password string
        :param data: encrypted password
        :return: plain password
        """
        return zlib.decompress(b64d(data))

    @staticmethod
    def is_string_true(test_str):
        if test_str is None:
            return False

        test_str = test_str.upper()
        if test_str == "TRUE" or test_str == "T" or test_str == "TR" or test_str == "TRU":
            return True

        if test_str == "YES" or test_str == "Y" or test_str == "YE":
            return True

        if test_str == "1":
            return True

        return False

    def get_dbconnection(self, connection_name):
        """
        Create a database connection based on the connection name defined (database -> connection) in config file.
        A maximum of 7 attempts will be made to get the successful database connection.
        Failure to obtain the database connection is reported as ERROR in log file.
        A failure record is NOT created in DS_LOG file
        :param connection_name: Name of the connection to be created
        :return: data connection
        """
        db_connection = None
        sleep = 4
        max_attempts = 7
        attempt_count = 1
        is_connection = None

        connection_data_node = self.get_connection_data(connection_name)
        if connection_data_node is None:
            raise BaseException(f"Unable to get database connection details for '{connection_name}'")

        user_id = connection_data_node.userid.text
        self.user_id = user_id
        self.real_schema = connection_data_node.real_schema.text
        encrypted_password = connection_data_node.password.text
        password = self.decrypt(encrypted_password)
        service_name = connection_data_node.service_name.text
        self.logger.debug(f"Connecting to database using user_id : [{user_id}], service_name : [{service_name}]")

        # If failed, make 7 attempts to get successful connection. For each attempt sleep twice the previous sleep time
        while attempt_count <= max_attempts:
            try:
                db_connection = cx_Oracle.connect(user_id, password, service_name)
                is_connection = True
                break
            except Exception as ex:
                self.logger.error(ex)
                self.logger.info(f'Connection failure attempt count : [{attempt_count}]')
                attempt_count += 1
                time.sleep(sleep)
                sleep = sleep * 2

        if is_connection is None:
            raise BaseException(f"After multiple attempts, unable to get {connection_name} database connection")

        self.logger.debug(f"Database connection successful. DB version : [{db_connection.version}]")

        return db_connection

    def send_html_email(self, event_code, to_email_address, message):
        """
        Sends email about the application status
        :param event_code: Event code to be notified
        :param to_email_address: Recipient address
        :param message: Email message
        :return:
        """

        final_to_email_address = to_email_address
        if type(to_email_address) is tuple:
            final_to_email_address = ", ".join(to_email_address)

        context = ssl.create_default_context()
        if not self.smtp_server:
            self.smtp_server = 'mail.ndchealth.com'

        s = smtplib.SMTP(self.smtp_server)
        s.ehlo()

        content = MIMEMultipart()
        if event_code == 'FAILED':
            subject = f'PYLOG[{self.app_id}]: {self.script_name} Log Alert'
        else:
            subject = f'PYLOG[{self.app_id}]: {self.script_name} Success Notification'
        content['subject'] = subject
        content['To'] = final_to_email_address
        content['From'] = 'DataServicesNotification@McKesson.com'
        body = f"<!DOCTYPE html><html><head><style>td {{ padding-right: 10px;}}</style></head>" \
               f"<body>Notification received with a log status of [{self.log_level}]<br><br>" \
               f"<table><tr><td>APP ID: </td><td>{self.app_name}</td></tr>" \
               f"<tr><td>Process: </td><td>{self.script_name}</td>" \
               f"</tr><tr><td>Scriptname: </td><td>{self.script_filename}</td></tr>" \
               f"<tr><td>Event Code: </td><td>{event_code}</td>" \
               f"</tr><tr><td>Post date: </td><td>{self.today}</td></tr><tr><td>Host: </td>" \
               f"<td>{self.hostname}</td></tr>" \
               f"<tr><td>PID: </td><td>{self.pid}</td></tr><tr><td>Path: </td>" \
               f'<td style="white-space:nowrapf">{self.current_working_dir}</td></tr></table> ' \
               f"<br><br> Log Message: {message}</body></html>"

        clear = f"Notification received with a log status of [{self.log_level}]\r\n" \
                f"APP ID: {self.app_name}]\r\n" \
                f"Process: [{self.script_name}]\r\n" \
                f"Event Code: [{event_code}]\r\n" \
                f"Post Date: [{self.today}]\r\n" \
                f"Host: [{self.hostname}]\r\n" \
                f"PID: [{self.pid}]\r\n" \
                f"Path: [{self.current_working_dir}]\r\n" \
                f"Log Message: {message}"

        # Record the MIME type text/html.
        # Attach parts into message container.
        # According to RFC 2046, the last part of a multipart message, in this case
        # the HTML message, is best and preferred.
        content.attach(MIMEText(body, 'html'))
        content.attach(MIMEText(clear, 'plain'))

        # Send the message
        try:
            s.send_message(content)
        except BaseException as be:
            print(be)
        finally:
            s.quit

    def send_html_custom_email(self, event_code, file_config, message, schema_name, table_name):
        """
        Sends email about the application status
        :param event_code: Event code to be notified
        :param to_email_address: Recipient address
        :param message: Email message
        :return:
        """

        final_to_email_address = file_config.failure_email
        if type(file_config.failure_email) is list:
            final_to_email_address = ", ".join(file_config.failure_email)

        context = ssl.create_default_context()
        if not self.smtp_server:
            self.smtp_server = 'mail.ndchealth.com'

        s = smtplib.SMTP(self.smtp_server)
        s.ehlo()

        content = MIMEMultipart()
        if event_code == 'FAILED':
            subject = f'PYLOG[{self.app_id}]: {self.script_name} Log Alert'
        else:
            subject = f'PYLOG[{self.app_id}]: {self.script_name} Success Notification'
        content['subject'] = subject
        content['To'] = final_to_email_address
        content['From'] = 'DataServicesNotification@McKesson.com'
        body = f"<!DOCTYPE html><html><head><style>td {{ padding-right: 10px;}}</style></head>" \
               f"<body><b>Monitoring Application Details:</b><br>" \
               f"<table><tr><td>APP ID: </td><td>{self.app_name}</td></tr>" \
               f"<tr><td>Process: </td><td>{self.script_name}</td>" \
               f"</tr><tr><td>Scriptname: </td><td>{self.script_filename}</td></tr>" \
               f"<tr><td>Event Code: </td><td>{event_code}</td>" \
               f"</tr><tr><td>Post date: </td><td>{self.today}</td></tr><tr><td>Host: </td>" \
               f"<td>{self.hostname}</td></tr>" \
               f"<tr><td>PID: </td><td>{self.pid}</td></tr><tr><td>Path: </td>" \
               f'<td style="white-space:nowrapf">{self.current_working_dir}</td></tr>' \
               f'</table> ' \
               f"<br><br><b>Error Details:</b>" \
               f"<table>" \
               f"<tr><td>Schema Name: </td><td>{schema_name}</td></tr>" \
               f"<tr><td>Table Name: </td><td>{table_name}</td></tr>" \
               f"<tr><td>Identify config using: </td><td>FILE_GROUP:'{file_config.file_group}', PROCESS: '{file_config.process}', FILE_NAME: '{file_config.actual_filename}'</td></tr>" \
               f"<tr><td>File Location: </td><td>{file_config.final_folder_name}</td></tr>" \
               f"<tr><td>Reason: </td><td>{message}</td></tr>" \
               f"</table>" \
               f"<br><br><b>Additional Message:</b>" \
               f"<table>" \
               f"<tr><td>{file_config.custom_notification_message}</td></tr>" \
               f"</table>" \
               f"</body></html>"

        clear = f"Notification received with a log status of [{self.log_level}]\r\n" \
                f"APP ID: {self.app_name}]\r\n" \
                f"Process: [{self.script_name}]\r\n" \
                f"Event Code: [{event_code}]\r\n" \
                f"Post Date: [{self.today}]\r\n" \
                f"Host: [{self.hostname}]\r\n" \
                f"PID: [{self.pid}]\r\n" \
                f"Path: [{self.current_working_dir}]\r\n" \
                f"Log Message: {message}"

        # Record the MIME type text/html.
        # Attach parts into message container.
        # According to RFC 2046, the last part of a multipart message, in this case
        # the HTML message, is best and preferred.
        content.attach(MIMEText(body, 'html'))
        # content.attach(MIMEText(clear, 'plain'))

        # Send the message
        try:
            s.send_message(content)
        except BaseException as be:
            print(be)
        finally:
            s.quit

    def log_monitoring(self, event_code, message, log_level):
        """
        Adds application run status record to DS_LOG table.
        :param event_code: Application event code
        :param message: Event message
        :return:
        """
        global default_email
        global success_email
        global failure_email

        monitoring_table = self.config.monitoring_log_table.text

        sql = f"""
                INSERT INTO {monitoring_table} (
                      PROCESS,
                      EVENT_CODE,
                      EVENT_DATE,
                      POST_DATE,
                      MESSAGE,
                      HOST,
                      USERNAME,
                      CMD_PID,
                      CMD_NAME,
                      PWD,
                      LOG_LEVEL
                    ) VALUES (
                      :v_process,
                      :v_event_code,
                      TO_TIMESTAMP(:v_event_date,'YYYY-MM-DD HH24:MI:SS.FF6'),
                      :v_post_date,
                      :v_message,
                      :v_host,
                      :v_username,
                      :v_cmd_pid,
                      :v_cmd_name,
                      :v_pwd,
                      :v_log_level
                    )
            """
        if log_level:
            log_level = str(log_level).upper()
            if log_level in ('INFO', 'FATAL', 'ERROR', 'WARN', 'DEBUG'):
                self.log_level = log_level

        if message:
            if type(message) is not str:
                message = message.__str__()

            if len(message) > 4000:
                message = message[0:3997] + "..."

        log_params = [self.script_name, event_code, datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f'), self.today,
                      message,
                      self.hostname,
                      self.current_username, self.pid, self.script_filename, self.current_working_dir, self.log_level]

        db_connection = self.get_dbconnection('dsmonitor')
        try:
            with db_connection.cursor() as cursor:

                APP_MAIL_SQL = """
                      SELECT
                        EMAIL
                      FROM
                        DS_APP_CONFIG
                      WHERE
                        APP_ID = :V_APP_ID
                    """

                PROCESS_MAIL_SQL = """
                      SELECT
                        SUCCESS_EMAIL,
                        FAILURE_EMAIL
                      FROM
                        DS_PROCESS_CONFIG
                      WHERE
                        PROCESS = :V_PROCESS
                    """

                # get default application level email
                cursor.execute(APP_MAIL_SQL, [self.app_id])
                default_email = cursor.fetchone()

                if default_email:
                    self.failure_email = default_email

                # get optional process level email
                cursor.execute(PROCESS_MAIL_SQL, [self.app_name])
                emails = cursor.fetchone()

                if emails:
                    success_email = emails[0]
                    failure_email = emails[1]

                    if success_email:
                        self.success_email = success_email

                    if failure_email:
                        self.failure_email = failure_email

                cursor.execute(sql, log_params)
                db_connection.commit()

        except Exception as error:
            err, = error.args
            err_message = f'Error code : {err.code}, messsage : {err.message}'
            self.logger.error(err_message)

        finally:
            db_connection.close()

        self.logger.debug(f'Event code : [{event_code}] record inserted into DS_LOG table')

        if event_code == 'SUCCESS' and self.success_email and self.log_level == 'INFO':
            self.send_html_email(event_code=event_code, to_email_address=self.success_email, message='Process completed successfully')
            self.logger.debug(f'Email sent for the event code : [{event_code}]')

        elif event_code == 'FAILED' and self.failure_email:
            self.send_html_email(event_code=event_code, to_email_address=self.failure_email, message=message)
            self.logger.debug(f'Email sent for the event code : [{event_code}]')

        elif log_level in ('FATAL', 'ERROR') and self.default_email:
            self.send_html_email(event_code=event_code, to_email_address=self.default_email, message=message)
            self.logger.debug(f'Email sent for the event code : [{event_code}]')

    def load_notification_parameter(self):
        """
        Get success and failure notification email address
        :return:
        """

        monitoring_process_config_table = self.config.monitoring_process_config_table.text
        sql = "select success_email, failure_email from {table} where APP_ID = '{app_id}' and PROCESS = '{process}'"
        query = sql.format(table=monitoring_process_config_table, app_id=self.app_name, process=self.script_name)
        self.logger.debug(query)

        db_connection = self.get_dbconnection('dsmonitor')
        cursor = db_connection.cursor()
        try:
            cursor.execute(query)
            result = cursor.fetchall()
            for row in result:
                self.success_email = row[0]
                self.failure_email = row[1]
            self.logger.debug(f'success_email : [{self.success_email}], failure_email : [{self.failure_email}]')
        except cx_Oracle.DatabaseError as de:
            err, = de.args
            err_message = f'Error code : {err.code}, messsage : {err.message}'
            raise BaseException(err_message)
        finally:
            cursor.close()
            db_connection.close()

    @staticmethod
    def get_time_millis():
        return int(round(time.time() * 1000))

    @staticmethod
    def get_date(date_type="today", delta_days=0):
        """
        Returns a date string of requested date_type

        :param date_type: 'today' (default), 'yesterday', 'tomorrow', 'days_ago', 'days_from_now', 'last_month_begin', 'last_month_end', 'last_month', 'this_month', 'next_month'
        :param delta_days: number of days ago/from now (applicable for 'days_ago' and 'days_from_now')
        :return: Date string in YYYYMMDD format
        """

        return_date = date.today()

        if date_type == "today":
            delta_days = 0

        elif date_type == "yesterday":
            return_date -= timedelta(days=1)

        elif date_type == "tomorrow":
            return_date += timedelta(days=1)

        elif date_type == "days_ago":
            return_date -= timedelta(days=delta_days)

        elif date_type == "days_from_now":
            return_date += timedelta(days=delta_days)

        elif date_type == "last_month_begin":
            return_date = return_date.replace(day=1) - timedelta(days=1)
            return_date = return_date.replace(day=1)

        elif date_type == "last_month_end":
            return_date = return_date.replace(day=1) - timedelta(days=1)

        elif date_type == "last_month":
            return_date = return_date.replace(day=1) - timedelta(days=1)
            return return_date.strftime("%Y%m")

        elif date_type == "this_month":
            return return_date.strftime("%Y%m")

        elif date_type == "next_month":
            return_date = return_date.replace(day=28) + timedelta(days=4)
            return return_date.strftime("%Y%m")

        else:
            raise BaseException(f"get_date(): bad type '{date_type}'.  Expecting 'today', 'yesterday', 'tomorrow', "
                                f"'days_ago', 'days_from_now', 'last_month_begin', 'last_month_end', 'last_month', "
                                f"'this_month', 'next_month'")

        return return_date.strftime("%Y%m%d")

    @staticmethod
    def date_text_to_datetime_obj(date_spec, anchor):
        """
        Internal method to parse date_spec and return a datetime object

        :param date_spec: 'YYYYMMDD'
        :param anchor: 'begin', 'end'
        :return: datetime object
        """

        match = re.match(r"^\s*(\d{4})(\d{2})\s*$", date_spec)
        if match:
            year = match.group(1)
            month = match.group(2)
            if anchor == "begin":
                dt_obj = datetime.strptime(f"{year}{month}01", "%Y%m%d").date()
            elif anchor == "end":
                days_in_month = monthrange(int(year), int(month))[1]
                dt_obj = datetime.strptime(f"{year}{month}{days_in_month}", "%Y%m%d").date()
            else:
                raise BaseException(f"{anchor} is an invalid anchor param (expecting 'begin' or 'end')")
        else:
            match = re.match(r"^\s*\d{4}\d{2}\d{2}\s*$", date_spec)
            if match:
                dt_obj = datetime.strptime(date_spec, "%Y%m%d").date()
            else:
                raise BaseException(f"{anchor} is an invalid date_spec param (expecting 'YYYYMM' or 'YYYYMMDD')")
        return dt_obj

    @staticmethod
    def date_spec_to_list(date_spec_list=[]):
        """
        Takes a csv list of date_specs and produces a list of all dates defined by date_spec_list

        :param date_spec_list:
        :return: list of all dates defined by date_spec_list
        """

        if date_spec_list is None:
            date_spec_list = []
        return_list = []

        if len(date_spec_list) < 1:
            raise BaseException("No date_spec_list provided.")

        for date_spec in date_spec_list:
            match = re.match(r"^\s*(\d{6,8})\s*$", date_spec)
            if match:
                start_date_spec = match.group(1)
                end_date_spec = start_date_spec
            else:
                match = re.match(r"^\s*(\d{6,8})\s*-\s*(\d{6,8})\s*$", date_spec)
                if match:
                    start_date_spec = match.group(1)
                    end_date_spec = match.group(2)
                else:
                    raise BaseException(f"date_spec_to_list(): Could not decipher date spec value of '{date_spec}'. "
                                        + "Valid syntax examples are: YYYYMMDD, YYYYMMDD-YYYYMMDD, YYYYMMDD, "
                                        + "YYYYMM-YYYYMM, YYYYMM, YYYYMM-YYYYMMDD, etc.")
            try:
                start_date_obj = Build.date_text_to_datetime_obj(start_date_spec, 'begin')
            except BaseException:
                raise BaseException(f"date_spec_to_list(): Could not convert start date spec of '{start_date_spec}' to "
                                    + "datetime object")
            try:
                end_date_obj = Build.date_text_to_datetime_obj(end_date_spec, 'end')
            except BaseException:
                raise BaseException(f"date_spec_to_list(): Could not convert end date spec of '{end_date_spec}' to "
                                    + "datetime object")
            for n in range(int((end_date_obj - start_date_obj).days) + 1):
                return_list.append((start_date_obj + timedelta(n)).strftime("%Y%m%d"))

        return_list.sort()
        return return_list


class HostnameFilter(logging.Filter):
    hostname = platform.node()

    def filter(self, record):
        record.hostname = HostnameFilter.hostname

        # Get only the machinename of the FQDN
        match = re.match("^[^\.]+", record.hostname)
        if match:
            record.hostname = match.group(0)

        return True
