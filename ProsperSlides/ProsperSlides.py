"""ProsperSlides.py

Utility for making/pushing weekly Prosper Market Show Sldies

Using: https://developers.google.com/slides API
-- python lib: https://developers.google.com/slides
"""

from datetime import datetime
from os import path, makedirs, access, W_OK#, R_OK

import requests
from plumbum import cli, local

import prosper.common.prosper_logging as p_logging
import prosper.common.prosper_config as p_config

HERE = path.abspath(path.dirname(__file__))
ME = __file__.replace('.py', '')
CONFIG_ABSPATH = path.join(HERE, 'ProsperSlides.cfg')
config = p_config.ProsperConfig(CONFIG_ABSPATH)
logger = p_logging.DEFAULT_LOGGER

DROPBOX = False
GDRIVE = False

def build_logger(
        log_name=ME,
        config=config
):
    """build a logger for the script to use.
    --avoids issue of library/app fighting loggers

    Args:
        log_name (str, optional): name for logfile, default scriptname
        config (:obj:`configparser.ConfigParser`, optional): [Logging] option overrides

    Returs:
        (:obj:`prosper.common.ProsperLogger`): log builder for appending options onto

    Note:
        Pushes logger onto gloabl

    """
    global logger
    log_builder = p_logging.ProsperLogger(
        log_name,
        'logs',
        config_obj=config
    )
    logger = log_builder.logger
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
            logger.error(
                'Unable to create path for outfile' +
                '\n\tpath=' + filepath +
                '\n\texception=' + repr(err_msg)
            )
            raise err_msg

    if not access(filepath, W_OK):
        logger.error(
            'Lacking proper permissions in path' +
            '\n\tpath=' + filepath
        )
        raise PermissionError

    if 'dropbox' in str(filepath).lower():
        global DROPBOX
        DROPBOX = True

    if 'google' in str(filepath).lower():
        global GDRIVE
        GDRIVE = True

    if DROPBOX and GDRIVE:
        raise Exception('path cannot both be gdrive & dropbox')

    return filepath

class ProsperSlides(cli.Application):
    """Plumbum CLI application to build EVE Prosper Market Show slidedeck"""
    _log_builder = build_logger()
    debug = cli.Flag(
        ['d', '--debug'],
        help='Debug mode, send data to local files'
    )

    @cli.switch(
        ['-v', '--verbose'],
        help='enable verbose logging')
    def enable_verbose(self):
        """toggle verbose output"""
        global logger
        self._log_builder.configure_debug_logger()
        logger = self._log_builder.logger

    outfile = test_filepath(
        path.join(local.env.home, 'Google Drive', 'Prosper Shownotes', 'Plots')
    )
    @cli.switch(
        ['-o', '--output'],
        str,
        help='base path to write plots to'
    )
    def set_output_file(self, filepath=outfile):
        """test to make sure path is ok"""
        filepath = test_filepath(filepath)

        self.outfile = filepath

    def main(self):
        logger.debug('hello world')
        logger.debug(self.outfile)

if __name__ == '__main__':
    ProsperSlides.run()
