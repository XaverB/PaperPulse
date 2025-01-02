import React, { useState, useEffect } from 'react';
import { Upload, Trash2, FileText, ChevronDown, ChevronUp, RefreshCw, Clock, CheckCircle, XCircle } from 'lucide-react';

const DocumentManager = () => {
  const [documents, setDocuments] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [expandedDoc, setExpandedDoc] = useState(null);
  const [uploadStatus, setUploadStatus] = useState(null);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [isDragging, setIsDragging] = useState(false);

  const fetchDocuments = async () => {
    setLoading(true);
    try {
      const response = await fetch('/api/documents');
      const data = await response.json();
      setDocuments(data);
    } catch (err) {
      setError('Failed to fetch documents');
    } finally {
      setLoading(false);
    }
  };

  const handleUpload = async (event) => {
    const file = event.target.files[0];
    if (!file) return;

    const formData = new FormData();
    formData.append('document', file);

    setUploadStatus('uploading');
    setUploadProgress(0);

    try {
      const progressInterval = setInterval(() => {
        setUploadProgress(prev => {
          if (prev >= 90) {
            clearInterval(progressInterval);
            return 90;
          }
          return prev + 10;
        });
      }, 500);

      await fetch('/api/documents', {
        method: 'POST',
        body: formData,
      });

      clearInterval(progressInterval);
      setUploadProgress(100);
      setUploadStatus('success');
      fetchDocuments();

      setTimeout(() => {
        setUploadStatus(null);
        setUploadProgress(0);
      }, 3000);
    } catch (err) {
      setUploadStatus('error');
      setError('Failed to upload document');
    }
  };

  const handleDelete = async (documentId) => {
    try {
      await fetch(`/api/documents/${documentId}`, {
        method: 'DELETE',
      });
      fetchDocuments();
    } catch (err) {
      setError('Failed to delete document');
    }
  };

  useEffect(() => {
    fetchDocuments();
  }, []);

  const toggleMetadata = (docId) => {
    setExpandedDoc(expandedDoc === docId ? null : docId);
  };

  const getStatusBadge = (status) => {
    const statusConfig = {
      'Processed': { color: 'bg-green-100 text-green-800', icon: CheckCircle },
      'Processing': { color: 'bg-blue-100 text-blue-800', icon: RefreshCw },
      'Error': { color: 'bg-red-100 text-red-800', icon: XCircle },
      'Pending': { color: 'bg-yellow-100 text-yellow-800', icon: Clock }
    };

    const config = statusConfig[status] || statusConfig['Pending'];
    const Icon = config.icon;

    return (
      <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${config.color}`}>
        <Icon className="w-3 h-3 mr-1" />
        {status}
      </span>
    );
  };

  return (
    <div className="max-w-5xl mx-auto p-6">
      <div className="bg-white rounded-lg shadow-sm mb-8">
        <div className="p-6 border-b">
          <h1 className="text-3xl font-bold">Document Processing Platform</h1>
        </div>
        <div className="p-6">
          {/* Upload Section */}
          <div
            className={`relative mb-6 ${isDragging ? 'ring-2 ring-blue-500' : ''}`}
            onDragOver={(e) => {
              e.preventDefault();
              setIsDragging(true);
            }}
            onDragLeave={() => setIsDragging(false)}
            onDrop={(e) => {
              e.preventDefault();
              setIsDragging(false);
              const file = e.dataTransfer.files[0];
              if (file) {
                const input = document.createElement('input');
                input.files = e.dataTransfer.files;
                handleUpload({ target: input });
              }
            }}
          >
            <label className="block">
              <div className="flex items-center justify-center w-full h-40 px-4 transition bg-gray-50 border-2 border-gray-300 border-dashed rounded-lg cursor-pointer hover:bg-gray-100">
                <div className="flex flex-col items-center">
                  <div className="p-4 mb-2 rounded-full bg-gray-100 hover:bg-white transition">
                    <Upload className="w-8 h-8 text-gray-500" />
                  </div>
                  <p className="text-sm text-gray-500">Drag and drop or click to upload</p>
                  <p className="text-xs text-gray-400 mt-1">PDF, DOC, DOCX, TXT (max 10MB)</p>
                </div>
                <input
                  type="file"
                  className="hidden"
                  onChange={handleUpload}
                  accept=".pdf,.doc,.docx,.txt"
                />
              </div>
            </label>

            {uploadStatus && (
              <div className="mt-4">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm font-medium">
                    {uploadStatus === 'uploading' ? 'Uploading...' : 
                     uploadStatus === 'success' ? 'Upload Complete!' : 'Upload Failed'}
                  </span>
                  <span className="text-sm text-gray-500">{uploadProgress}%</span>
                </div>
                <div className="w-full bg-gray-200 rounded-full h-2">
                  <div 
                    className="bg-blue-600 h-2 rounded-full transition-all duration-300"
                    style={{ width: `${uploadProgress}%` }}
                  />
                </div>
              </div>
            )}
          </div>

          {/* Error Display */}
          {error && (
            <div className="p-4 mb-6 border border-red-200 bg-red-50 text-red-800 rounded-lg">
              {error}
            </div>
          )}

          {/* Documents List */}
          <div className="space-y-4">
            {loading ? (
              <div className="text-center py-8">
                <RefreshCw className="w-8 h-8 animate-spin mx-auto text-gray-400 mb-2" />
                <p className="text-gray-500">Loading documents...</p>
              </div>
            ) : documents.length === 0 ? (
              <div className="text-center py-12 bg-gray-50 rounded-lg">
                <FileText className="w-12 h-12 mx-auto text-gray-400 mb-2" />
                <p className="text-gray-500">No documents found</p>
                <p className="text-sm text-gray-400">Upload a document to get started</p>
              </div>
            ) : (
              <div className="grid gap-4">
                {documents.map((doc) => (
                  <div key={doc.id} className="bg-white border rounded-lg overflow-hidden transition hover:shadow-md">
                    <div className="p-4">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-4">
                          <div className="p-2 bg-gray-100 rounded-lg">
                            <FileText className="w-6 h-6 text-gray-500" />
                          </div>
                          <div>
                            <h3 className="font-medium">{doc.fileName}</h3>
                            <p className="text-sm text-gray-500">
                              {new Date(doc.processedDate).toLocaleDateString()}
                            </p>
                          </div>
                        </div>
                        <div className="flex items-center space-x-3">
                          {getStatusBadge(doc.status)}
                          <button
                            onClick={() => toggleMetadata(doc.id)}
                            className="p-2 hover:bg-gray-100 rounded-lg"
                          >
                            {expandedDoc === doc.id ? (
                              <ChevronUp className="w-5 h-5" />
                            ) : (
                              <ChevronDown className="w-5 h-5" />
                            )}
                          </button>
                          <button
                            onClick={() => handleDelete(doc.id)}
                            className="p-2 text-red-600 hover:bg-red-50 rounded-lg"
                          >
                            <Trash2 className="w-5 h-5" />
                          </button>
                        </div>
                      </div>

                      {/* Metadata Section */}
                      {expandedDoc === doc.id && (
                        <div className="mt-4 pl-12 border-t pt-4">
                          <div className="grid grid-cols-2 gap-4">
                            <div>
                              <h4 className="font-medium mb-2 text-sm text-gray-600">Document Info</h4>
                              <dl className="grid grid-cols-2 gap-2 text-sm">
                                <dt className="text-gray-500">Content Type:</dt>
                                <dd>{doc.contentType}</dd>
                                <dt className="text-gray-500">Status:</dt>
                                <dd>{doc.status}</dd>
                                <dt className="text-gray-500">Processed:</dt>
                                <dd>{new Date(doc.processedDate).toLocaleString()}</dd>
                              </dl>
                            </div>
                            <div>
                              <h4 className="font-medium mb-2 text-sm text-gray-600">Extracted Data</h4>
                              <dl className="text-sm space-y-2">
                                {Object.entries(doc.extractedMetadata).map(([key, value]) => (
                                  <div key={key}>
                                    <dt className="text-gray-500">{key}:</dt>
                                    <dd className="mt-1 text-sm text-gray-900 break-words">
                                      {value}
                                    </dd>
                                  </div>
                                ))}
                              </dl>
                            </div>
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default DocumentManager;