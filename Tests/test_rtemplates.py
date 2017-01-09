"""test_rtemplates.py

Pytest functions for validating rtemplate collections

"""
from os import path, listdir
import json

import pytest

import prosper.common.prosper_logging as p_logging
HERE = path.abspath(path.dirname(__file__))
ROOT = path.dirname(HERE)
ME = __file__.replace(HERE, 'test')

## TODO: add logger for help? ##
#LOGBUILDER = p_logging.ProsperLogging(
#    'test_rtemplates',
#    '.'
#)
#logger = LOGBUILDER.logger

ROBJECT_OVERRIDES = {
    'quantmod':{"skeleton.TA":"skeletonTA"}
}
R_REQUIREMENTS_FILE = 'r_requirements.txt'
R_DELIMITER = '=='
def test_rpy2_integration():
    """validate rpy2 can load correctly"""
    ## Try to import rpy (test R_HOME path) ##
    import rpy2.robjects as robjects
    import rpy2
    from rpy2.robjects.packages import importr

    req_filepath = path.join(ROOT, R_REQUIREMENTS_FILE)
    with open(req_filepath, 'r') as req_fh:
        raw_req = req_fh.read().splitlines()

    ## Test that requirements are in .libPaths() ##
    for requirement in raw_req:
        package, version = requirement.split(R_DELIMITER)
        package = package.replace(' ', '')

        if package in ROBJECT_OVERRIDES:
            importr(
                package,
                robject_translations=ROBJECT_OVERRIDES[package]
            )
        else:
            importr(package)

RTEMPLATE_PATH = path.join(ROOT, 'ProsperSlides', 'R_templates')
def test_matched_pairs():
    """validate that every R file has a JSON pair"""
    template_filelist = listdir(RTEMPLATE_PATH)

    R_files = []
    json_files = []
    orphan_files = []
    for file in template_filelist:
        if '.r' in file:
            file = file.replace('.r', '')
            R_files.append(file)
        elif '.json' in file:
            file = file.replace('.json', '')
            json_files.append(file)
        else:
            orphan_files.append(file)

    ## make sure there are no non R/json files
    assert not bool(orphan_files) #file in path isn't .json or .R

    ## make sure every R file has a json pair
    assert not bool(
        set(R_files) - set(json_files)
    )

def test_format_map():
    """validate that R template can map values"""
    template_filelist = listdir(RTEMPLATE_PATH)

    R_files = []
    json_files = []
    for file in template_filelist:
        if '.r' in file:
            file = file.replace('.r', '')
            R_files.append(file)
        elif '.json' in file:
            file = file.replace('.json', '')
            json_files.append(file)


    for template in R_files:
        template_filepath = path.join(RTEMPLATE_PATH, template + '.r')
        metadata_filepath = path.join(RTEMPLATE_PATH, template + '.json')

        with open(template_filepath, 'r') as t_fp:
            r_text = t_fp.read()

        try:
            with open(metadata_filepath, 'r') as m_fp:
                metadata = json.load(m_fp)
        except Exception as err:
            print(metadata_filepath)
            raise err

        format_dict = {}
        for key in metadata['required_args']:
            format_dict[key] = 'TEST'

        ## Actual test: apply `format_map` to r_text#
        try:
            r_text = r_text.format_map(format_dict)
        except Exception as err:
            print(template_filepath)
            raise err
