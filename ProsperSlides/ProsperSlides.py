"""ProsperSlides.py

Utility for making/pushing weekly Prosper Market Show Sldies

Using: https://developers.google.com/slides API
-- python lib: https://developers.google.com/slides
"""

from datetime import datetime
from os import path, makedirs, access, W_OK#, R_OK

import ujson as json
import requests
from plumbum import cli, local

import Helpers as ps_helper
#import prosper.common.prosper_logging as p_logging
#import prosper.common.prosper_config as p_config

HERE = path.abspath(path.dirname(__file__))
ME = __file__.replace('.py', '')
CONFIG_ABSPATH = path.join(HERE, 'ProsperSlides.cfg')
config = ps_helper.CONFIG
logger = ps_helper.DEFAULT_LOGGER


def path_platform(filepath):
    """figure out which imagehost/sharing platform is being used

    Args:
        filepath (str): path to dump directory

    Returns:
        (:obj:`Helpers.HostPlatform`): Enum of which platform is being used

    """
    host = ps_helper.HostPlatform.ERROR
    types_found = 0

    if 'dropbox' in str(filepath).lower():
        host = ps_helper.HostPlatform.DROPBOX
        types_found += 1
    elif 'google' in str(filepath).lower():
        host = ps_helper.HostPlatform.DROPBOX
        types_found += 1
    else:
        raise ps_helper.UnsupportedHost('Unable to resolve host in=' + str(filepath))

    if types_found != 1:
        raise ps_helper.ConfusingHosts('Multiple possible hosts identified in=' + str(filepath))

    return host

def load_graph_profile(profile_filepath):
    """load profile for making graphs"""
    try:
        with open(profile_filepath, 'r') as filehandle:
            graph_profile_obj = json.load(filehandle)
    except Exception as err_msg:
        logger.error(
            'Unable to load graph profile from file:' +
            '\n\tfilepath=' + profile_filepath,
            exc_info=True
        )
        raise err_msg

    return graph_profile_obj

class ProsperSlides(cli.Application):
    """Plumbum CLI application to build EVE Prosper Market Show slidedeck"""
    _log_builder = ps_helper.build_logger('ProsperSlides')  #TODO: fix ME?
    debug = cli.Flag(
        ['d', '--debug'],
        help='Debug mode, send data to local files'
    )

    @cli.switch(
        ['-v', '--verbose'],
        help='enable verbose logging')
    def enable_verbose(self):
        """toggle verbose output"""

        self._log_builder.configure_debug_logger()
        ps_helper.LOGGER = self._log_builder.logger

    outfile = ps_helper.test_filepath(
        path.join(local.env.home, 'Dropbox', 'Prosper Shownotes', 'Plots')
    )
    platform = ps_helper.HostPlatform.ERROR
    @cli.switch(
        ['-o', '--output'],
        str,
        help='base path to write plots to'
    )
    def set_output_file(self, filepath=outfile):
        """test to make sure path is ok"""
        self.outfile = ps_helper.test_filepath(filepath)
        self.platform = path_platform(filepath)

    graph_profile = load_graph_profile(path.join(HERE, 'default_graphlist.json'))
    @cli.switch(
        ['-p', '--profile'],
        str,
        help='Profile to build plots from (.json)'
    )
    def load_profile(self, profile_filepath):
        """load profile for making graphs"""
        self.graph_profile = load_graph_profile(profile_filepath)

    def main(self):
        global logger
        logger = self._log_builder.logger
        ps_helper.LOGGER = logger #TODO: this seems sloppy?
        logger.debug('hello world')
        logger.debug(self.outfile)

if __name__ == '__main__':
    ProsperSlides.run()
