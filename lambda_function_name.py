import json
import os
import boto3
import botocore
import logging

from PDFNetPython3 import *

TMP_INPUT_PATH = '/tmp/'
TMP_OUTPUT_PATH = '/tmp/'

s3 = boto3.resource('s3')

def ocr_process(event, context):
    body = json.loads(event['body'])
    
    # Get S3 file key from event
    document_key =  body['file_key']
    ocr_module = body['ocr_module']
    
    # Get S3 bucket names
    S3_INPUTS_BUCKET = os.environ['S3_INPUTS_BUCKET']
    S3_OUTPUTS_BUCKET = os.environ['S3_OUTPUTS_BUCKET']
    
    try:
        # Lambda with VPC need S3 VPC endpoint check this for tutorial https://www.youtube.com/watch?v=uvKWJ4c1EYc
        s3.Bucket(S3_INPUTS_BUCKET).download_file(document_key, TMP_OUTPUT_PATH + document_key)
    except botocore.exceptions.ClientError as e:
        if e.response['Error']['Code'] == "404":
            print("The object does not exist.")
        else:
            raise

    # Run file through OCR
    PDFNet.Initialize("pdftron:OEM:pdf.online::WLM+:AMS(29290331):987FEB533C2E21EC17927B7151826905581F8675BA5C5240D0029233F5C7")
    
    ocr_module_name = 'Tesseract 4'
    if (ocr_module.lower() == 'iris'):
        PDFNet.AddResourceSearchPath("/mnt/ocr_module/IRISOCRModuleLinux/Lib/")
        ocr_module_name = 'IRIS iDRS'
        logging.warning('Using IRIS iDRS OCR module')
    else:
        PDFNet.AddResourceSearchPath("/opt/OCRModuleLinux/Lib/")
        logging.warning('Using Tesseract 4 OCR module')
    
    
    if not OCRModule.IsModuleAvailable():
        print("""
        Unable to run OCRTest: PDFTron SDK OCR module not available.
        ---------------------------------------------------------------
        The OCR module is an optional add-on, available for download
        at http://www.pdftron.com/. If you have already downloaded this
        module, ensure that the SDK is able to find the required files
        using the PDFNet::AddResourceSearchPath() function.""")
    else:
        # A) Process image without specifying options, default language - English - is used
        # --------------------------------------------------------------------------------
        doc = PDFDoc()

        # B) Run OCR on the input file with options
        OCRModule.ImageToPDF(doc, TMP_INPUT_PATH + document_key, None)

        # C) Save the result
        output_file = document_key[:-4] + '-ocr.pdf'
        doc.Save(TMP_OUTPUT_PATH + output_file, 0)
    
        # D) Upload file to S3 bucket
        try:
            response = s3.Bucket(S3_OUTPUTS_BUCKET).upload_file(TMP_OUTPUT_PATH + output_file, output_file)
        except botocore.exceptions.ClientError as e:
            return {
                "statusCode": 404
            }

    body = {
        "message": "File successfully processed by " + ocr_module_name +" OCR Module",
        "file": output_file
    }

    response = {
        "statusCode": 200,
        "body": json.dumps(body)
    }

    response["headers"] = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
    }

    return response

