function aadidev
    switch "$argv"
        case "is a dumbass"
            echo "yes, he is a dumbass"
        case "is smart" "is cool"
            echo "cap. detected."
        case ""
            echo "aadidev is currently a certified dumbass. Pass any phrase after 'aadidev' to roast him further."
        case "*"
            set roasts \
                                "Facts: aadidev $argv (and honestly that's being generous)." \
                                "System scan confirmed: aadidev $argv." \
                                "Even the Linux kernel agrees that aadidev $argv." \
                                "404: aadidevs's braincells not found. Definitely $argv."
            echo $roasts[(random 1 (count $roasts))]
    end
end
