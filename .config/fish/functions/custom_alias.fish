function fusuma_restart
    pkill -f fusuma
    fusuma -d &
end
