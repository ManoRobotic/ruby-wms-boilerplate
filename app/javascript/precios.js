document.addEventListener("DOMContentLoaded", function () {
    const preciosDiv = document.querySelector("#precios-container");
  
    if (preciosDiv) {
      setInterval(() => {
        fetch("/precios")
          .then((response) => response.text())
          .then((html) => {
            preciosDiv.innerHTML = html;
          });
      }, 60000); // Actualiza cada 60 segundos
    }
  });
  