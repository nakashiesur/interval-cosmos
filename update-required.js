// Fixed relative destination: no externally supplied redirect URL.
setTimeout(() => location.replace(new URL('./', location.href).href), 3500);
