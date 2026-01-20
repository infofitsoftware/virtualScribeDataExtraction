FROM public.ecr.aws/lambda/python:3.11

# Upgrade pip first
RUN pip install --upgrade pip

# Install numpy first (with specific version that has pre-built wheels)
RUN pip install --no-cache-dir numpy==1.26.4

# Install dependencies (numpy is already installed, so it won't try to build from source)
RUN pip install --no-cache-dir pyarrow==14.0.1 pandas==2.1.4 psycopg2-binary==2.9.9

# Copy Lambda function
COPY lambda_function.py ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler
CMD [ "lambda_function.lambda_handler" ]

