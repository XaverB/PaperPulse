import React, { useState, useEffect } from 'react';
import { Upload, Trash2, FileText, ChevronDown, ChevronUp, RefreshCw, Clock, CheckCircle, XCircle } from 'lucide-react';
import config from "./config";

interface DocumentMetadata {
  id: string;
  FileName: string;
  ProcessedDate: string;
  Status: string;
  ContentType: string;
  DocumentType: string;
  ExtractedMetadata: Record<string, string>;
}

const DocumentManager: React.FC = () => {
  const [documents, setDocuments] = useState<DocumentMetadata[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [expandedDoc, setExpandedDoc] = useState<string | null>(null);
  const [uploadStatus, setUploadStatus] = useState<'uploading' | 'success' | 'error' | null>(null);
  const [uploadProgress, setUploadProgress] = useState<number>(0);
  const [isDragging, setIsDragging] = useState<boolean>(false);

  const fetchDocuments = async (): Promise<void> => {
    setLoading(true);
    try {
      const response = await fetch(`${config.apiBaseUrl}/documents?code=${config.functionKey}`, {
        headers: {
          'Content-Type': 'application/json'
        }
      });
      if (!response.ok) {
        throw new Error('Failed to fetch documents');
      }
      const data = await response.json();
      setDocuments(data);
    } catch (err) {
      setError('Failed to fetch documents');
    } finally {
      setLoading(false);
    }
  };

  const handleUpload = async (event: React.ChangeEvent<HTMLInputElement> | { target: { files: FileList } }): Promise<void> => {
    const file = event.target.files?.[0];
    if (!file) return;
  
    const formData = new FormData();
    formData.append('document', file);
  
    setUploadStatus('uploading');
    setUploadProgress(0);
  
    try {
      console.log('Starting upload for file:', file.name);
      
      const progressInterval = setInterval(() => {
        setUploadProgress(prev => {
          if (prev >= 90) {
            clearInterval(progressInterval);
            return 90;
          }
          return prev + 10;
        });
      }, 500);
  
      const response = await fetch(`${config.apiBaseUrl}/documents/upload?code=${config.functionKey}`, {
        method: 'POST',
        body: formData,
        headers: {
          'Content-Disposition': `attachment; filename="${file.name}"`
        }
      });
  
      if (!response.ok) {
        const errorText = await response.text();
        console.error('Upload failed:', response.status, errorText);
        throw new Error(`Upload failed: ${response.status} ${errorText}`);
      }
  
      clearInterval(progressInterval);
      setUploadProgress(100);
      setUploadStatus('success');
      await fetchDocuments(); // Wait for the documents to be fetched
  
      setTimeout(() => {
        setUploadStatus(null);
        setUploadProgress(0);
      }, 3000);
    } catch (err) {
      console.error('Upload error:', err);
      setUploadStatus('error');
      setError(err instanceof Error ? err.message : 'Failed to upload document');
    }
  };

  const handleDelete = async (documentId: string): Promise<void> => {
    try {
      const response = await fetch(`${config.apiBaseUrl}/documents/${documentId}?code=${config.functionKey}`, {
        method: 'DELETE',
      });
      
      if (!response.ok) {
        throw new Error('Failed to delete document');
      }
      
      await fetchDocuments();
    } catch (err) {
      setError('Failed to delete document');
    }
  };

  useEffect(() => {
    fetchDocuments();
  }, []);

  const toggleMetadata = (docId: string): void => {
    setExpandedDoc(expandedDoc === docId ? null : docId);
  };

  const getStatusBadge = (status: string) => {
    const statusConfig: Record<string, { color: string; icon: React.FC }> = {
      'Processed': { color: 'bg-green-100 text-green-800', icon: CheckCircle },
      'Processing': { color: 'bg-blue-100 text-blue-800', icon: RefreshCw },
      'Error': { color: 'bg-red-100 text-red-800', icon: XCircle },
      'Pending': { color: 'bg-yellow-100 text-yellow-800', icon: Clock }
    };

    const config = statusConfig[status] || statusConfig['Pending'];
    const Icon = config.icon;

    return (
      <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${config.color}`}>
        <span className="w-auto h-auto mr-1">
          <Icon />
        </span>
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
            onDragOver={(e: React.DragEvent) => {
              e.preventDefault();
              setIsDragging(true);
            }}
            onDragLeave={() => setIsDragging(false)}
            onDrop={(e: React.DragEvent) => {
              e.preventDefault();
              setIsDragging(false);
              const files = e.dataTransfer.files;
              if (files.length > 0) {
                handleUpload({ target: { files } });
              }
            }}
          >
            <label className="block">
              <div className="flex items-center justify-center w-full h-40 px-4 transition bg-gray-50 border-2 border-gray-300 border-dashed rounded-lg cursor-pointer hover:bg-gray-100">
                <div className="flex flex-col items-center">
                  <div className="p-4 mb-2 rounded-full bg-gray-100 hover:bg-white transition">
                    <span className="w-8 h-8 text-gray-500">
                      <Upload />
                    </span>
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
                <span className="w-8 h-8 animate-spin mx-auto text-gray-400 mb-2">
                  <RefreshCw />
                </span>
                <p className="text-gray-500">Loading documents...</p>
              </div>
            ) : documents.length === 0 ? (
              <div className="text-center py-12 bg-gray-50 rounded-lg">
                <span className="w-12 h-12 mx-auto text-gray-400 mb-2">
                  <FileText />
                </span>
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
                            <span className="w-6 h-6 text-gray-500">
                              <FileText />
                            </span>
                          </div>
                          <div className="text-left">
                            <h3 className="font-medium">{doc.FileName}</h3>
                            <h3 className="font-small text-gray-500">{doc.DocumentType}</h3>
                            <p className="text-sm text-gray-500">
                              {new Date(doc.ProcessedDate).toLocaleDateString()}
                            </p>
                          </div>
                        </div>
                        <div className="flex items-center space-x-3">
                          {getStatusBadge(doc.Status)}
                          <button
                            onClick={() => toggleMetadata(doc.id)}
                            className="p-2 hover:bg-gray-100 rounded-lg"
                          >
                            {expandedDoc === doc.id ? (
                              <span className="w-5 h-5">
                                <ChevronUp />
                              </span>
                            ) : (
                              <span className="w-5 h-5">
                                <ChevronDown />
                              </span>
                            )}
                          </button>
                          <button
                            onClick={() => handleDelete(doc.id)}
                            className="p-2 text-red-600 hover:bg-red-50 rounded-lg"
                          >
                            <span className="w-5 h-5">
                              <Trash2 />
                            </span>
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
                                <dd>{doc.ContentType}</dd>
                                <dt className="text-gray-500">Status:</dt>
                                <dd>{doc.Status}</dd>
                                <dt className="text-gray-500">Processed:</dt>
                                <dd>{new Date(doc.ProcessedDate).toLocaleString()}</dd>
                              </dl>
                            </div>
                            <div>
                              <h4 className="font-medium mb-2 text-sm text-gray-600">Extracted Data</h4>
                              {doc.ExtractedMetadata && Object.keys(doc.ExtractedMetadata).length > 0 ? (
                                <dl className="text-sm space-y-2">
                                  {Object.entries(doc.ExtractedMetadata).map(([key, value]) => (
                                    <div key={key}>
                                      <dt className="text-gray-500">{key}:</dt>
                                      <dd className="mt-1 text-sm text-gray-900 break-words">
                                        {value}
                                      </dd>
                                    </div>
                                  ))}
                                </dl>
                              ) : (
                                <p className="text-sm text-gray-500">No metadata extracted</p>
                              )}
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