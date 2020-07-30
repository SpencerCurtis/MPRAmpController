# MPRAmpController

`MPRAmpController` is a Vapor program that controls the [Monoprice "6 Zone Home Audio Multizone Controller and Amplifier Kit"](https://www.monoprice.com/product?p_id=10761). In theory this should also work for the [Dayton Audio DAX66](https://www.daytonaudio.com/product/1252/dax66-6-source-6-zone-distributed-audio-system) __but has not been tested__. 

Control is done using the RS-232 port with either a Raspberry Pi or Mac and a serial to USB cable. I'm using [this one](https://www.amazon.com/dp/B00QUZY4UG/ref=cm_sw_em_r_mt_dp_U_xJQaFbN6SVJ4M). The current implementation has some trouble when used with a Raspberry Pi for some reason. I hope to have this worked out because I'd prefer not to sacrifice my Mac mini to just control this system.

