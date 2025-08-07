from flask import Flask, render_template

# Create an instance of the Flask class
app = Flask(__name__)

# Define a route for the home page
@app.route('/')
def hello():
    # Render the new, professional-looking HTML page
    return render_template('index.html')

# Note: The Gunicorn server will run this 'app' object.
# The if __name__ == "__main__": block is not needed for production.