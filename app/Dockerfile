FROM python:3.9-slim
#setting working directory
WORKDIR /app
#copying all the files
COPY . .

RUN pip install Flask

# Exposing port 5000
EXPOSE 5000

# Running the application
CMD ["python", "main.py"]
