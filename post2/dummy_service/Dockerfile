FROM python:3.8-slim

COPY . /
RUN pip3 install -r requirements.txt && pip3 install awscli
CMD ["python3", "run_worker.py"]
