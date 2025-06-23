###################################
# Jinja2-live parser Dockerfile
# Version: 1.0
# Author:  PJO2
# Usage:
#    git clone https://github.com/PJO2/jinja2-live
#    docker build -t jinja2-live jinja2-live
#    docker run --rm -p 8080:8080 jinja2-live
#    From browser, use the host address or name : http://host:8080
###################################

# Pull base image.
FROM python:latest
COPY . /data
WORKDIR /data

# Install dependencies
RUN  pip3 install -r requirements.txt

# Change bind host
RUN sed -i 's/host=config.HOST/host="0.0.0.0"/g' config.py

# Expose port to Host
EXPOSE 8080

# Define default command.
CMD ["python3", "parser.py"]

