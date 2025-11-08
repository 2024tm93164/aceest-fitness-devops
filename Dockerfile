# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /usr/src/app

COPY requirements.txt .

# Install necessary packages (Flask, gunicorn, pytest)
RUN pip install --no-cache-dir -r requirements.txt

# This includes ACEest_Fitness.py and test_app.py
COPY . .

# --- Security Enhancement ---
# 'adduser' is for debian-based images (like python:slim)
RUN adduser --system --no-create-home --group appuser
USER appuser
# --------------------------

# Expose the port the app runs on (matches Gunicorn command)
EXPOSE 5000

# Run the application using gunicorn (best practice for production)
# CMD format: ["executable", "param1", "param2", ...]
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "ACEest_Fitness:app"]

