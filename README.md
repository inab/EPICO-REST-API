EPICO / BLUEPRINT Data Analysis Portal REST API
=======================================

This API is needed by EPICO / BLUEPRINT Data Analysis Portal version 1.0 and later.

Installation procedures (dependencies, Apache setup, etc...) are available at [INSTALL.md](INSTALL.md).

Endpoints
--------

* GET /	It returns the ids of available domains, along with a brief description

* GET /:domain	It returns the domain information, if it could be instantiated

* GET /:domain/model	It returns the model, in JSON format (if applicable)

* GET /:domain/model/CV	It returns the list of controlled vocabularies related to the model.

* GET /:domain/model/CV/:cv_id	It returns a brief description of this controlled vocabulary

* GET /:domain/model/CV/:cv_id/terms	It returns the terms for given CV id (disease,tissue,cell)

* POST /:domain/model/CV/:cv_id/terms	It returns the terms for given CV id (disease,tissue,cell), filtered by input terms

* GET /:domain/model/CV/:conceptDomain/:concept/:column	It returns all the controlled vocabularies associated to the column

* GET /:domain/model/CV/:conceptDomain/:concept/:column/terms	It returns all the terms from the controlled vocabularies associated to the column

* POST /:domain/model/CV/:conceptDomain/:concept/:column/terms	It returns all the terms from the controlled vocabularies associated to the column, filtered by input terms

/:domain/sdata	It returns the identifiers of all the donors, specimens, samples and experiments registered in the database.
/:domain/sdata/_all	It returns all the donors, specimens, samples and experiments registered in the database.
/:domain/sdata/donor	It returns the identifiers of all the registered donors.
/:domain/sdata/donor/:donor_id	It returns the donor whose donor id is this. Special '_all' donor id returns all the donors.
/:domain/sdata/specimen	It returns the identifiers of all the registered specimens.
/:domain/sdata/specimen/:specimen_id	It returns the specimen whose specimen id is this. Special '_all' specimen id returns all the specimens.
/:domain/sdata/sample	It returns the identifiers of all the registered samples.
/:domain/sdata/sample/:sample_id	It returns the sample whose sample id is this. Special '_all' sample id returns all the samples.
/:domain/sdata/experiment	It returns the identifiers of all the registered experiments.
/:domain/sdata/experiment/:experiment_id	It returns the experiment whose experiment id is this. Special '_all' experiment id returns all the experiments.
/:domain/analysis/metadata	It returns the identifiers of all the registered analysis.
/:domain/analysis/metadata/:analysis_id	It returns the analysis metadata whose analysis id is this. Special '_all' analysis id returns all the analysis.
/:domain/analysis/data/:chromosome/:chromosome_start/:chromosome_end
/:domain/analysis/data/:chromosome/:chromosome_start/:chromosome_end/stats
/:domain/analysis/data/:chromosome/:chromosome_start/:chromosome_end/detailed_stats
/:domain/genomic_layout/:chromosome/:chromosome_start/:chromosome_end
/:domain/features?query=
/:domain/features/suggest?query=
