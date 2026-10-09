import "./style.css";

const result = document.getElementById("result");
const button = document.getElementById("refresh");

async function loadApi() {
  result.textContent = "Contacting backend...";

  try {
    const response = await fetch("/api/hello", {
      cache: "no-store"
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const data = await response.json();
    result.textContent = JSON.stringify(data, null, 2);
  } catch (error) {
    result.textContent = `API error: ${error.message}`;
  }
}

button.addEventListener("click", loadApi);
loadApi();
