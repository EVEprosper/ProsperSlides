# ProsperSlides
Use Google's Slides API to automate show layout

# Tool Info
Windows-based collection of apps to help publish the [EVE Prosper Market Show](https://www.youtube.com/user/EVEProsper).  

1. Use [rpy2](https://rpy2.readthedocs.io/en/version_2.8.x/) to generate common week-to-week plots for slides
2. Use [Dropbox](https://www.dropbox.com/developers/documentation/python) to generate share-links
3. Use [Google Slides API](https://developers.google.com/slides/) to render weekly presentation

# Environment Prerequisites

* ODBC connections to EVE Prosper data
    * `randomboy_new` (or similar) connection to Prosper data
    * `sde_lookup` schema of [EVE SDE](https://www.fuzzwork.co.uk/dump/)
* R (3.3.x) and [rpy2](https://rpy2.readthedocs.io/en/version_2.8.x/overview.html#installation) hooks
    * `R_HOME`: path to R.exe EX: `C:\Program Files\R\R_3.3.1`
    * `R_USER`: `getwd()` path EX: `%USERPROFILE%`
* Python 3.5+
    * NOTE: rpy2 wheel included for windows install.  [use precompiled wheel](http://www.lfd.uci.edu/~gohlke/pythonlibs/#rpy2)
    * [ProsperCommon](https://manage.fury.io/dashboard/lockefox/package/UzNwMDN) hosted at GemFury.  `--extra-index-url=https://pypi.fury.io/jyd5j4yse83c9UW64tP7/lockefox/`
* [Dropbox](https://www.dropbox.com/install) client application

TODO: include `/Scripts` for environment setup and rpy2 validation

# Using the App:
`ProsperSlides.py` is a [Plumbum CLI app](http://plumbum.readthedocs.io/en/latest/cli.html).  Use `-h` for robust versioning information.  It is highly suggested to run in a [virtual environment](http://docs.python-guide.org/en/latest/dev/virtualenvs/)

ProsperSlides will run through default configuration without any special options.  Also automatically logs its progress locally.  Can use Discord as an alerting platform if provided a valid webhook in the `[LOGGING]` section inside `ProsperSlides.cfg`.
