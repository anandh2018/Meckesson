def auto_str(cls):
    def __str__(self):
        return '%s(%s)' % (
            type(self).__name__,
            ', '.join('%s=%s' % item for item in vars(self).items())
        )

    cls.__str__ = __str__
    return cls


@auto_str
class FileConfig:
    """
    Class Object to hold MCS Request parameters
    """
    file_group = None
    process = None
    process_description = None
    file_name = None
    file_date_qualifier = None
    file_cutoff_time = None
    file_type = None
    file_inbound_folder = None
    file_inbound_processed_folder = None
    file_inbound_failed_folder = None
    file_outbound_folder = None
    file_outbound_processed_folder = None
    file_outbound_failed_folder = None
    number_of_failed_attempt = None
    notify_through_email = None
    failure_email = None
    notify_through_dslog = None
    custom_validation_script = None
    custom_notification_message = None
    entry_date = None
    entered_by = None

    def __init__(self):
        pass

