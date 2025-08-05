# Use a lightweight Python base image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Copy application files
COPY . .

# Install dependencies, including the gunicorn web server
RUN pip install Flask gunicorn

# Expose port 80 to the outside world
EXPOSE 80

# Command to run the application using gunicorn on port 80
# This tells gunicorn to run the 'app' object from the 'main.py' file
CMD ["gunicorn", "--bind", "0.0.0.0:80", "main:app"]