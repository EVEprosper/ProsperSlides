"""Plotting.py

Hub for building plots

"""

from os import path

import rpy2.robjects as robjects
import rpy2
from rpy2.robjects.packages import importr
import ujson as json

import Helpers as ps_helper

def plot(
        plot_template,
        plot_filename,
        plot_args,
        logger=ps_helper.DEFAULT_LOGGER
):
    """plot magic

    Args:
        plot_template (str): special info for filling out template
        plot_filename (str): filename to print to
        plot_args (:obj:`dict`): specific template data
        logger (:obj:`logging.logger`, optional): logging handle for logs

    Returns:
        (str): path to plotted image

    """
    r_template, metadata = get_template(
        plot_template,
        logger=logger
    )

    plot_args['img_path'] = plot_filename
    if set(plot_args.keys()) - set(metadata['required_args']):
        #use set() to find unique keys.  Should return empty
        logger.debug('plot_args={0}'.format(plot_args.keys()))
        logger.debug('metadata={0}'.format(metadata['required_args']))
        logger.warning('unique keys={0}'.format(
            set(plot_args.keys()) - set(metadata['required_args'])
        ))
        raise KeyError('Plot profile and metadata do not match')

    r_template = r_template.format_map(plot_args)   #apply required_args

    ## import libaries for R ##
    logger.debug('-- Building up environment')
    for package in metadata['package_requires']:
        if package in metadata['package_overrides']:
            #quantmod is weird
            util = importr(
                package,
                robject_translations=metadata['package_overrides'][package]['robject_translations']
            )
        else:
            util = importr(package)
        #util.chooseCRANmirror(ind=1)    #install package: https://rpy2.readthedocs.io/en/version_2.8.x/robjects_rpackages.html#installing-removing-r-packages

    if 'robjects' in metadata:
        for robject in metadata['robjects']:
            robjects.r(robject)

    ## Execute R script
    logger.debug('-- Executing R')
    try:
        robjects.r(r_template)
    except Exception as err_msg:
        logger.error(
            'EXCEPTION: rpy/plot failed' +
            '\n\tplot_template={0}'.format(plot_template) +
            '\n\tplot_filename={0}'.format(plot_filename),
            exc_info=True
        )

    #TODO: detach crashes python
    ### clean up before exiting ##
    #logger.debug('-- Cleaning up environment')
    #for package in metadata['package_requires']:
    #    robjects.r(
    #        'detach("package:{0}", unload=TRUE)'.format(package)
    #    )

    return plot_args['img_path']

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
