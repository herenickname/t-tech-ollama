#!/bin/bash

# Убедитесь, что у вас есть необходимые права для выполнения скрипта:
# chmod +x build_models.sh

# Функция для установки и очистки после сборки
build_model() {
  MODEL_NAME=$1
  FILE_NAME=$2
  SYSTEM_FILE=$3
  LICENSE_FILE=$2/LICENSE

  echo "Стартуем сборку модели: $MODEL_NAME"

  # Скачиваем модель
  ./hfdownloader_linux_amd64_1.4.2 -m $MODEL_NAME

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

  # Конвертируем модель в формат GGUF
  python3 convert_hf_to_gguf.py --outfile ../${FILE_NAME}_bf16.gguf --outtype bf16 ../${FILE_NAME}

  # Квантование модели
  ./build/bin/llama-quantize ../${FILE_NAME}_bf16.gguf Q4_K_M

  # Создание модели
  ollama create -f Modelfile herenickname/$MODEL_NAME:q4_k_m

  # Тестирование модели
  ollama run --verbose $MODEL_NAME:q4_k_m "Как называется модель?"

  # Удаление временных файлов
  echo "Удаление временных файлов для $MODEL_NAME"
  rm -rf ggml-model-Q4_K_M.gguf
  rm -rf ../${FILE_NAME}_bf16.gguf
  rm -rf $FILE_NAME
  rm -rf Modelfile

  echo "Сборка модели $MODEL_NAME завершена!"
}

# Основной процесс
echo "Обновление apt"
apt update

echo "Установка ollama"
curl -fsSL https://ollama.com/install.sh | sh

echo "Установка hfdownloader"
wget https://github.com/bodaay/HuggingFaceModelDownloader/releases/download/1.4.2/hfdownloader_linux_amd64_1.4.2

# Устанавливаем все зависимости
echo "Установка зависимостей"
apt install git cmake build-essential python3 pip python3.11-venv

# Клонируем репозиторий llama.cpp
echo "Клонирование llama.cpp"
git clone https://github.com/ggerganov/llama.cpp
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

# Сборка моделей t-lite и t-pro
build_model "t-tech/T-lite-it-1.0" "t-tech_T-lite-it-1.0" "system.t-lite"
build_model "t-tech/T-pro-it-1.0" "t-tech_T-pro-it-1.0" "system.t-pro"

# Завершаем процесс
echo "Все модели успешно собраны!"
