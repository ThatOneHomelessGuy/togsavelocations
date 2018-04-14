# TOG Save Locations
(togsavelocations)

Setup/save custom teleport locations for each map.

* Configurable access flags (using the [TOG Flag System](https://www.togcoding.com/togcoding/index.php#TOGFlagSystem)) both for saving new locations and teleporting to saved locations.
* Option to show glowing orbs at teleport locations.
* Command to get your current coordinates so non-admins can suggest locations to admins with access and not need to know client cvars to see coordinates.
* Rooms are named for easier identification.
* Each map has its own config saved, allowing editing (by those with FTP access) when the map isn't active.
* Admin menu integration to make listing, removing, and creating new teleport locations easy.


## Installation:
* Put togsavelocations.smx in the following folder: /addons/sourcemod/plugins/


## CVars:
<details><summary>Click to View CVars</summary>
<p>

* **tsl_version** - TOG Save Locations: Version

* **tsl_flag_setnew** - Players with this flag will be able to create new teleport locations.

* **tsl_flag_tp** - Players with this flag will be able to use the saved teleports.

* **tsl_showglows** - Show glowing orbs at teleport locations? (0 = Disabled, 1 = Enabled).
</p>
</details>

Note: After changing the cvars in your cfg file, be sure to rcon the new values to the server so that they take effect immediately.

## Player Commands:
<details><summary>Click to View Player Commands</summary>
<p>

* **sm_locs** - [No Description Provided]

* **sm_locations** - [No Description Provided]

* **sm_saves** - [No Description Provided]

* **sm_newsave** - [No Description Provided]

* **sm_createsave** - [No Description Provided]

* **sm_saveloc** - [No Description Provided]

* **sm_reloadlocs** - [No Description Provided]

* **sm_getcoords** - [No Description Provided]

* **sm_coords** - [No Description Provided]
</p>
</details>


## _____SOME_SPOILER_TITLE_____:
<details><summary>Click to Open Spoiler</summary>
<p>
<pre><code>
_____STUFF_INSIDE_SPOILER_____
</code></pre>
</p>
</details>





### Check out my plugin list: http://www.togcoding.com/togcoding/index.php
