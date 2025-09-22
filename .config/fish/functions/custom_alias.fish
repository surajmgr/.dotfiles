function fusuma_restart
    pkill -f fusuma
    fusuma -d &
end

function rekeyd
    sudo cp ~/.config/keyd/keyd.conf /etc/keyd/keyd\ virtual\ keyboard.conf
    sudo cp ~/.config/keyd/keyd.conf /etc/keyd/Apple_Internal_Keyboard_Trackpad.conf
    sudo systemctl restart keyd
end
