# Inicializar Projeto

## Objetivo
Este guia mostra como compilar e rodar o app no seu celular pela primeira vez e nas proximas vezes.

## Requisitos
- Flutter instalado e configurado no PATH
- Android Studio (ou SDK Android instalado)
- Um celular Android com depuracao USB ativada
- Cabo USB para conectar o celular

## Primeira vez (primeiro build no celular)
1. No celular: ative "Opcoes do desenvolvedor" e "Depuracao USB".
2. Conecte o celular via USB e aceite a permissao de depuracao.
3. No computador, verifique se o dispositivo aparece:
   - Execute: flutter devices
4. Na raiz do projeto, baixe dependencias:
   - Execute: flutter pub get
5. Rode o app no celular:
   - Execute: flutter run

## Proximas vezes (apos o primeiro build)
1. Conecte o celular via USB e confirme a depuracao (se solicitado).
2. Na raiz do projeto, rode:
   - Execute: flutter run

## Dicas
- Se houver mais de um dispositivo, especifique o alvo:
  - Execute: flutter run -d <device_id>
- Para listar os IDs dos dispositivos:
  - Execute: flutter devices
