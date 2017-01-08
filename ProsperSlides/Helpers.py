"""Helpers.py

"global" library for ProsperSlides.

"""
from os import path, makedirs, access, W_OK
from enum import Enum

import ujson as jsonschema
import jsonschema

import prosper.common.prosper_logging as p_logging
import prosper.common.prosper_config as p_config

HERE = path.abspath(path.dirname(__file__))

CONFIG_ABSPATH = path.join(HERE, 'ProsperSlides.cfg')
CONFIG = p_config.ProsperConfig(CONFIG_ABSPATH)
DEFAULT_LOGGER = p_logging.DEFAULT_LOGGER
LOGGER = DEFAULT_LOGGER

class HostPlatform(Enum):
    """Enumerated types for hosting platform"""
    DROPBOX = 'dropbox'
    GDRIVE = 'google drive'
    ERROR = 'NOTSUPPORTED'

def build_logger(
        log_name,
        config=CONFIG
):
    """build a logger for the script to use.
    --avoids issue of library/app fighting loggers

    Args:
        log_name (str): name for logfile, default scriptname
        config (:obj:`configparser.ConfigParser`, optional): [Logging] option overrides

    Returs:
        (:obj:`prosper.common.ProsperLogger`): log builder for appending options onto

    Note:
        Pushes logger onto gloabl

    """
    global LOGGER
    log_dir = path.join(HERE, 'logs')
    log_builder = p_logging.ProsperLogger(
        log_name,
        log_dir,
        config_obj=config
    )
    LOGGER = log_builder.logger
    return log_builder

def test_filepath(filepath):
    """test filepath, make sure it exists and has proper permissions

    Args:
        filepath (str): filepath abspath > relpath

    Returns:
        (str): filepath (or exception)

    """
    if not path.exists(filepath):
        try:
            makedirs(filepath, exist_ok=True)
        except Exception as err_msg:
            LOGGER.error(
                'Unable to create path for outfile' +
                '\n\tpath=' + filepath +
                '\n\texception=' + repr(err_msg)
            )
            raise err_msg

    if not access(filepath, W_OK):
        LOGGER.error(
            'Lacking proper permissions in path' +
            '\n\tpath=' + filepath
        )
        raise PermissionError

    return filepath

def validate_json(
    test_obj,
    json_schema_path
):
    """use jsonschema to validate object

    Args:
        test_obj (:obj:`dict`): JSON serialized dictionary
        json_schema (str): path to jsonschema file (abspath > relpath)

    Returns:
        (bool): passed/failed validation

    """
    pass

class ProsperSlidesException(Exception):
    """project-level Exception class for custom exceptions"""
    pass
class UnsupportedHost(ProsperSlidesException):
    """Image host platform not supported"""
    pass
class ConfusingHosts(ProsperSlidesException):
    """multiple image host platforms raised in single path"""
    pass
