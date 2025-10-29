FROM python:3.11-slim
WORKDIR /app
COPY hello.py /app
RUN pip install --no-cache-dir flask
EXPOSE 3000
CMD ["python", "hello.py"]
