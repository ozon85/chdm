#!/bin/bash

# используемые переменные
DMSN='display-manager.service' #display manager service name
DMM='display manager' # display manager marker
AllowNotTTY="" # маркер для работы не только в tty

# массивы сообщений на языках
declare -A Mess_RunInTTY
Mess_RunInTTY[en]="Run in TTY instead of the PTS"
Mess_RunInTTY[ru]="Запустите в TTY вместо PTS"
declare -A Mess_CurrentDM
Mess_CurrentDM[en]="Current $DMM"
Mess_CurrentDM[ru]="Текущий $DMM"
declare -A Mess_UnableToDetectCurrentDM
Mess_UnableToDetectCurrentDM[en]="Unable to detect current $DMM service"
Mess_UnableToDetectCurrentDM[ru]="Не удалось определить текущий сервис $DMM"
declare -A Mess_NoDMFounded
Mess_NoDMFounded[en]="No one $DMM service founded"
Mess_NoDMFounded[ru]="Ни одного $DMM не найдено"
declare -A Mess_AvailableList
Mess_AvailableList[en]="List of available:"
Mess_AvailableList[ru]="Список доступных:"
declare -A Mess_SelectNumberToChange
Mess_SelectNumberToChange[en]="Select number to change"
Mess_SelectNumberToChange[ru]="Выберите номер для смены"
declare -A Mess_SelectedService
Mess_SelectedService[en]="Selected service"
Mess_SelectedService[ru]="Выбрана служба"
declare -A Mess_Failed
Mess_Failed[en]="Failed"
Mess_Failed[ru]="Не удалось"
declare -A Mess_ToRun
Mess_ToRun[en]="to run"
Mess_ToRun[ru]="запустить"
declare -A Mess_toEnable
Mess_toEnable[en]="to enable"
Mess_toEnable[ru]="включить"
declare -A Mess_toDisable
Mess_toDisable[en]="to disable"
Mess_toDisable[ru]="отключить"
declare -A Mess_toStop
Mess_toStop[en]="to stop"
Mess_toStop[ru]="остановить"



# список индексов массива сообщений
LangList=${!Mess_RunInTTY[@]}

function InTTY(){ tty|grep -E 'tty[0-9]+'; }

function debug(){ echo >&2 "$@"; }

#Получить описание указанной службы $1
function ServiceDescription(){ systemctl show -P Description $1 2>/dev/null; }

#Получить путь к сервису указанной службы $1
#function ServiceUnitFile(){ systemctl show -P FragmentPath $1; }

# список доступных сервисов строками в виде sdd.service, исключены @.service
function AvailableServices(){ systemctl --no-pager list-unit-files --type=service|cut -d' ' -f1|grep -E '[^@]\.service'; }

# Проверка строки $1 на соответствие 'display manager'  Код возврата 0 если содержит
function DMInLine(){ [ -z "$1" ] && return 1; grep -i "$DMM" <<<"$1"; }

# Список всех служб с описанием содержащим display manager, содержит строку со службой display-manager.service
function DisplayManagerServices(){
 #получаем все возможные службы
UF=`AvailableServices`||return 1
 #получаем описания для каждой службы
for F in $UF;do
  SD=`ServiceDescription $F` && SDasDM=`DMInLine "$SD"` &&
    echo $F':'"$SDasDM" # и если описание подходит под display-manager, выводим эту связку
done
}

# выводит текст статуса службы display-manager.service до первой пустой строки
function CurrentDMServiceInfo(){
systemctl --no-pager status $DMSN|
while read K;do  
  [ -z "$K" ] &&
    return 0||
    echo "$K"
done
}

# распознать название службы в строке $1 по первому попавшемуся признаку .service
function GetFirstServiceInLine(){
[ -z "$1" ]&&return 1;
#echo $@
for A in $@;do
  [[ "$A" =~ [a-zA-Z]\.service ]]&&{ echo $A;return 0; }
done;
}

# Проверяет строку $1 положительное число это или нет
function LineIsNumber(){ [[ "$1" =~ ^[0-9]+$ ]]; }

# Проверяет что число $1 больше чем $2 и меньше (или равно) чем $3
function NumberGreaterAndLower(){ [ "$1" -ge "$2" ]&&[ "$1" -le "$3" ]; }






########################################################################################################################

# Определяем язык вывода
[ -z "$Lang" ] && Lang=`cut -d_ -f1<<<"$LANG"`
[ -n "$Lang" ] && [[ " $LangList " == *" $Lang "* ]]||Lang=en #если определили язык из локали, и он не списке доступных языков, установим его как английский
#[ -z "$Lang" ]&& Lang=en

# если маркер разрешения работы не в TTY (например в PTS) не установлен, и мы не в TTY, выход с ошибкой - защита запуска из под экранного менеджера, который будет остановлен
[ -n "$AllowNotTTY" ]||InTTY >/dev/null||{ debug ${Mess_RunInTTY[$Lang]}; exit 1; }



#echo Получаем текущий экранный менеджер #$DMSN
CDMr=`CurrentDMServiceInfo`|| exit $?
Fl=`head -n 1 <<<"$CDMr"`
echo "${Mess_CurrentDM[$Lang]}:"	"$Fl"


# узнаём название сервиса экранного менеджера
FSIL=`GetFirstServiceInLine $Fl`
#echo "Название сервиса: $FSIL"
[ -z "$FSIL" ]&&{ echo >&2 "${Mess_UnableToDetectCurrentDM[$Lang]}"; exit 1; }
CURSERV=$FSIL

#получаем список служб экранных мэнэджеров с описанием display manager и фильтруем строку с display-manager.service
DMSs=`DisplayManagerServices|grep -iv $DMSN`
[ -z "$DMSs" ]&&{ echo >&2 "${Mess_NoDMFounded[$Lang]}"; exit 1; } #ни одного DM не найдено
echo "${Mess_AvailableList[$Lang]}"
cat -n <<<"$DMSs"

# узнаём пределы ввода выбора
MaxChoise=`wc -l <<<"$DMSs"`

# Ожидаем ввода от пользователя, предлагая варианты действий
UserChoise=0
while [ "$UserChoise" -eq 0 ];do
  read -p "${Mess_SelectNumberToChange[$Lang]} $DMM:" K;  
  if [ -n "$K" ];then # если введено хоть что-то  
  if LineIsNumber "$K";then #Проверить что введено число
    #проверить, что число в пределах варианта выбора
    NumberGreaterAndLower $K 1 $MaxChoise && UserChoise=$K
  #else
  #  echo "Введено не число"
  fi
fi
done

#Получаем службу по номеру выбора
NEWSERV=`head -n $UserChoise <<<"$DMSs"|tail -n 1|cut -d: -f1`
echo "${Mess_SelectedService[$Lang]}:" "$NEWSERV"


# провести останов и замену текущей службы
if systemctl stop $CURSERV;then
  if systemctl disable $CURSERV;then
    if systemctl enable $NEWSERV;then
      systemctl start $NEWSERV||{ echo >&2 "${Mess_Failed[$Lang]} ${Mess_ToRun[$Lang]} $NEWSERV"; exit 4; }
    else echo >&2 "${Mess_Failed[$Lang]} ${Mess_toEnable[$Lang]} $NEWSERV"; exit 3;fi
  else echo >&2 "${Mess_Failed[$Lang]} ${Mess_toDisable[$Lang]} $CURSERV"; exit 2;fi
else echo >&2 "${Mess_Failed[$Lang]} ${Mess_toStop[$Lang]} $CURSERV"; exit 1;fi
exit 0