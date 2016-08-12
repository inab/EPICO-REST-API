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

* POST /:domain/model/CV/terms	It returns all the terms from the controlled vocabularies, filtered by input terms. If the input is empty, it returns an empty array.

* GET /:domain/model/CV/:cv_id	It returns a brief description of this controlled vocabulary

* GET /:domain/model/CV/:cv_id/terms	It returns the terms for given CV id (disease,tissue,cell)

* POST /:domain/model/CV/:cv_id/terms	It returns the terms for given CV id (disease,tissue,cell), filtered by input terms

* GET /:domain/model/CV/:conceptDomain/:concept/:column	It returns all the controlled vocabularies associated to the column

* GET /:domain/model/CV/:conceptDomain/:concept/:column/terms	It returns all the terms from the controlled vocabularies associated to the column

* POST /:domain/model/CV/:conceptDomain/:concept/:column/terms	It returns all the terms from the controlled vocabularies associated to the column, filtered by input terms

* GET /:domain/sdata	It returns the identifiers of all the donors, specimens, samples and experiments registered in the database.

* GET /:domain/sdata/_all	It returns all the donors, specimens, samples and experiments registered in the database.

* GET /:domain/sdata/donor	It returns the identifiers of all the registered donors.

* GET /:domain/sdata/donor/:donor_id	It returns the donor whose donor id is this. Special '_all' donor id returns all the donors.

* GET /:domain/sdata/specimen	It returns the identifiers of all the registered specimens.

* GET /:domain/sdata/specimen/:specimen_id	It returns the specimen whose specimen id is this. Special '_all' specimen id returns all the specimens.

* GET /:domain/sdata/sample	It returns the identifiers of all the registered samples.

* GET /:domain/sdata/sample/:sample_id	It returns the sample whose sample id is this. Special '_all' sample id returns all the samples.

* GET /:domain/sdata/experiment	It returns the identifiers of all the registered experiments.

* GET /:domain/sdata/experiment/:experiment_id	It returns the experiment whose experiment id is this. Special '_all' experiment id returns all the experiments.

* GET /:domain/analysis/metadata	It returns the identifiers of all the registered analysis.

* GET /:domain/analysis/metadata/:analysis_id	It returns the analysis metadata whose analysis id is this. Special '_all' analysis id returns all the analysis.

* GET /:domain/analysis/data/:chromosome/:chromosome_start/:chromosome_end
* GET /{domain}/analysis/data/{chromosome}:{chromosome_start}-{chromosome_end}	It returns the results which are in this range

* GET /:domain/analysis/data/:chromosome/:chromosome_start/:chromosome_end/stream
* GET /{domain}/analysis/data/{chromosome}:{chromosome_start}-{chromosome_end}/stream	It returns a handler to fetch results chunk by chunk

* POST /:domain/analysis/data/fetchStream	Sending the handler receive with previous call, you are fetching the results chunk by chunk

* GET /:domain/analysis/data/:chromosome/:chromosome_start/:chromosome_end/count
* GET /{domain}/analysis/data/{chromosome}:{chromosome_start}-{chromosome_end}/count	It counts the number of related results per analysis

* GET /:domain/analysis/data/:chromosome/:chromosome_start/:chromosome_end/stats
* GET /{domain}/analysis/data/{chromosome}:{chromosome_start}-{chromosome_end}/stats	It gives detailed stats	(only for BLUEPRINT)

* GET /:domain/genomic_layout/:chromosome/:chromosome_start/:chromosome_end
* GET /{domain}/genomic_layout/{chromosome}:{chromosome_start}-{chromosome_end}	It returns the genomic layout features found in the range

* GET /:domain/features?q=	It returns the features, their types and their coordinates matching the input query (which can be an identifier, for instance)

* GET /:domain/features/suggest?q=	It returns the features suggested by the input prefix query (useful for autocompletion)
