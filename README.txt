SWERTY TASTATURLAYOUT - INSTALLATIONSVEJLEDNING
================================================

Indhold:
  dk_swerty            - Selve layoutfilen
  install-swerty.sh    - Installationsscript
  README.txt           - Denne fil


INSTALLATION
------------

1. Kopiér hele denne mappe til den nye maskine (USB, netværk osv.)

2. Åbn en terminal i mappen og kør:

      sudo bash install-swerty.sh

3. Genstart GDM (login-manageren) for at aktivere layoutet:

      sudo systemctl restart gdm

   ELLER log blot ud og ind igen.


HVIS LAYOUTET IKKE VIRKER VED LOGIN-SKÆRMEN
--------------------------------------------

Kør dette manuelt og genstart GDM bagefter:

   sudo dpkg-reconfigure keyboard-configuration

Vælg:
  - Keyboard model: Generic 105-key PC (intl.)
  - Country of origin: Danish
  - Keyboard layout: Danish - Swerty
  - Key to function as AltGr: Default
  - Compose key: No compose key


HVIS LAYOUTET IKKE VIRKER EFTER LOGIN
--------------------------------------

Kør dette som din normale bruger (uden sudo):

   gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'dk+swerty')]"
