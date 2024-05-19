# Use the official Python image from the Docker Hub
FROM --platform=linux/amd64 python:3.8-slim-buster

# Set the working directory
WORKDIR /app

# Update the package lists and install git and MySQL client libraries
RUN apt-get update && \
    apt-get install -y git default-libmysqlclient-dev build-essential && \
    rm -rf /var/lib/apt/lists/*

# Upgrade pip
RUN pip install --upgrade pip

# Define environment variable
ENV FLASK_APP=crudapp.py

# Copy the entrypoint script into the container
COPY entrypoint.sh /entrypoint.sh

# Make the script executable
RUN chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Copy the application code into the container
COPY . .

# Install Python dependencies
RUN pip install -r requirements.txt

# Expose the port that the app runs on
EXPOSE 5000