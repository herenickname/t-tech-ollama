#!/bin/bash

# Убедитесь, что у вас есть необходимые права для выполнения скрипта:
# chmod +x build_models.sh

# Функция для установки ollama, если она не установлена
install_ollama() {
  if ! command -v ollama &> /dev/null; then
    echo "ollama не найдена. Устанавливаю..."
    curl -fsSL https://ollama.com/install.sh | sh
  else
    echo "ollama уже установлена."
  fi
}

# Функция для установки и очистки после сборки
build_model() {
  MODEL_NAME=$1
  FILE_NAME=$2
  SYSTEM_FILE=$3
  LICENSE_FILE=$2/LICENSE

  echo "Стартуем сборку модели: $MODEL_NAME"

  # Скачиваем модель
  ./hfdownloader_linux_amd64_1.4.2 -m $MODEL_NAME

  # Конвертируем модель в формат GGUF
  python3 llama.cpp/convert_hf_to_gguf.py --outfile ./${FILE_NAME}_bf16.gguf --outtype bf16 ./${FILE_NAME}

  # Квантование модели
  ./llama.cpp/build/bin/llama-quantize ./${FILE_NAME}_bf16.gguf Q4_K_M

  # Чтение содержимого файлов
  template_content=$(cat ./template)
  system_content=$(cat ./$SYSTEM_FILE)
  license_content=$(cat ./$LICENSE_FILE)

  # Создание Modelfile для модели
  echo "Создание файла Modelfile для $MODEL_NAME"
  cat > Modelfile <<EOL
FROM ./ggml-model-Q4_K_M.gguf
TEMPLATE """$template_content"""
SYSTEM """$system_content"""
LICENSE """$license_content"""
EOL
  echo "Файл Modelfile успешно создан."

  # Создание модели
  ollama create -f Modelfile herenickname/$FILE_NAME:q4_k_m

  # Тестирование модели
  ollama run --verbose herenickname/$FILE_NAME:q4_k_m "Как называется модель?"

  # Удаление временных файлов
  echo "Удаление временных файлов для $MODEL_NAME"
  rm -rf ggml-model-Q4_K_M.gguf
  rm -rf ${FILE_NAME}_bf16.gguf
  rm -rf $FILE_NAME
  rm -rf Modelfile

  echo "Сборка модели $MODEL_NAME завершена!"
}

# Основной процесс
echo "Обновление apt"
apt update

# Устанавливаем ollama, если она еще не установлена
install_ollama

echo "Установка hfdownloader"
wget https://github.com/bodaay/HuggingFaceModelDownloader/releases/download/1.4.2/hfdownloader_linux_amd64_1.4.2
chmod +x hfdownloader_linux_amd64_1.4.2

# Устанавливаем все зависимости
echo "Установка зависимостей"
apt install -y git cmake build-essential python3 pip python3.11-venv

# Клонируем репозиторий llama.cpp
echo "Клонирование llama.cpp"
git clone --depth 1 https://github.com/ggerganov/llama.cpp
cd llama.cpp

# Собираем llama.cpp
echo "Сборка llama.cpp"
cmake -B build
cmake --build build --config Release -j

# Создаем виртуальное окружение
echo "Создание виртуального окружения"
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Возвращаемся в корень
cd ..

# Сборка моделей t-lite и t-pro
build_model "t-tech/T-lite-it-1.0" "t-tech_T-lite-it-1.0" "system.t-lite"
build_model "t-tech/T-pro-it-1.0" "t-tech_T-pro-it-1.0" "system.t-pro"

# Завершаем процесс
echo "Все модели успешно собраны!"
