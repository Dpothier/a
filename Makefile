#################################################################################
# GLOBALS                                                                       #
#################################################################################

PROJECT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
PROJECT_NAME = a
PYTHON_INTERPRETER = python3
ifeq (latest,newest)
	PYTHON_VERSION = 3
else
	PYTHON_VERSION=newest
endif


ifeq (,$(shell which conda))
    HAS_CONDA=False
else
    HAS_CONDA=True
endif

ifeq (,$(shell which git))
	HAS_GIT=False
else
	HAS_GIT=True
endif

ifeq (,$(shell which dvc))
	HAS_DVC=False
else
	HAS_DVC=True
endif
#################################################################################
# COMMANDS                                                                      #
#################################################################################

## Install Python Dependencies
requirements: test_environment
	$(PYTHON_INTERPRETER) -m pip install -U pip setuptools wheel
	$(PYTHON_INTERPRETER) -m pip install -r requirements.txt

## Make Dataset
data: requirements
	$(PYTHON_INTERPRETER) src/data/make_dataset.py data/raw data/processed

## Delete all compiled Python files
clean:
	find . -type f -name "*.py[co]" -delete
	find . -type d -name "__pycache__" -delete

## Lint using flake8
lint:
	pylint src
	pylint tests

yapf:
	yapf src --recursive --in-place
	yapf tests --recursive --in-place

tests:
	pytests tests

## Set up python interpreter environment
init_environment:
ifeq (True,$(HAS_CONDA))
	@echo ">>> Detected conda, creating conda environment."
	@conda create -n $(PROJECT_NAME) python=$(PYTHON_VERSION) msgpack-python pylint anaconda -y -q
	@conda install pytorch torchvision cudatoolkit=10.1 -c pytorch -y
	@conda run -n $(PROJECT_NAME) python -m pip install --upgrade pip -q
	@while read -r requirement; do \
	    echo $(requirement); \
	    conda run -n $(PROJECT_NAME) python -m pip install --upgrade "$$requirement" -q; \
	done < requirements.txt
else
	$(error Conda not install.)
endif

init_git:
ifeq (True,$(HAS_GIT))
	@echo ">>> Init of the git repository."
	@git init -q
	@git add .
	@git commit -m "initial commit"
	@hub create
	@git push -u origin master
else
	$(error Git or hub not installed.)
endif

init_dvc:
ifeq (True,$(HAS_DVC))
	@echo ">>> Init of DVC"
	@dvc init -q
	@dvc add data/raw -q
else
	$(error DVC not install.)
endif


## Test python environment is setup correctly
test_environment:
	$(PYTHON_INTERPRETER) test_environment.py

#################################################################################
# PROJECT RULES                                                                 #
#################################################################################



#################################################################################
# Self Documenting Commands                                                     #
#################################################################################

.DEFAULT_GOAL := help

# Inspired by <http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html>
# sed script explained:
# /^##/:
# 	* save line in hold space
# 	* purge line
# 	* Loop:
# 		* append newline + line to hold space
# 		* go to next line
# 		* if line starts with doc comment, strip comment character off and loop
# 	* remove target prerequisites
# 	* append hold space (+ newline) to line
# 	* replace newline plus comments by `---`
# 	* print line
# Separate expressions are necessary because labels cannot be delimited by
# semicolon; see <http://stackoverflow.com/a/11799865/1968>
.PHONY: help
help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@echo
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')
