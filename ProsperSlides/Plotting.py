"""Plotting.py

Hub for building plots

"""

from os import path

import rpy2
import ujson as json

import ProsperSlides.Helpers as ps_helper

def plot(
        plot_profile,
        plot_filename,
        plot_args,
        logger=ps_helper.DEFAULT_LOGGER
):
    """plot magic

    Args:
        plot_profile (:obj:`dict`): special info for filling out template
        plot_filename (str): filename to print to
        plot_args (:obj:`dict`): specific template data
        logger (:obj:`logging.logger`, optional): logging handle for logs

    Returns:
        (str): path to plotted image

    """
    r_template, metadata = get_template(
        plot_profile,
        logger=logger
    )

GRAPH_TEMPLATE_PATH = ps_helper.CONFIG.get('PATHS', 'r_templates')
def get_template(
        template_name,
        template_path=GRAPH_TEMPLATE_PATH,
        logger=ps_helper.DEFAULT_LOGGER
):
    """Fetch R code/metadata for building plots

    Args:
        template_name (str): basename for template to graph to
        template_path (str, optional): basepath to templates (abspath > relpath)
        logger (:obj:`logging.logger`, optional): logging handle for logs

    Returns:
        (str): loaded (unformatted) .R file from template
        (:obj:`dict`): paired metadata for building plot

    """
    r_template_path = path.join(
        template_path,
        template_name + '.R'
    )
    logger.debug('--r_template_path={0}'.format(r_template_path))
    metadata_template_path = path.join(
        template_path,
        template_name + '.json'
    )
    logger.debug('--metadata_template_path={0}'.format(metadata_template_path))
    try:
        with open(r_template_path, 'r') as r_fh:
            r_text = r_fh.read()
    except Exception as err_msg:
        logger.error(
            'EXCEPTION: unable to read .R file' +
            '\n\tfilepath={0}'.format(r_template_path),
            exc_info=True
        )
        raise err_msg

    try:
        with open(metadata_template_path, 'r') as meta_fh:
            meta_obj = json.load(meta_fh)
    except Exception as err_msg:
        logger.error(
            'EXCEPTION: unable to read .json metadata file' +
            '\n\tfilepath={0}'.format(metadata_template_path),
            exc_info=True
        )
        raise err_msg

    return r_text, meta_obj
