Sound@ theme;

bool played = false;
double attempts = 0;
const double themeVolume = 1.5;
double volume = 0.0;
double restartDelay = 0.5;

double musicVolume = 1.0;
double prevMusicVol = 1.0, prevMasterVol = 1.0, prevSFXVol = 1.0;

FileList list("data/music/theme", "*.ogg", true);

void playRandomTheme() {
	if(list.length < 1) {
		playDefaultTheme();
		settings::bEnableMTE = false;
		error("Could not find valid sound file in data/music/theme, disabling Multiple Themes...");
		return;
	}
	string filepath = list.path[randomi(0, list.length - 1)];
	@theme = playTrack(filepath, loop = false, pause = true);
	if(theme !is null) {
		theme.volume = 0;
		volume = 0;
		theme.paused = false;
		played = true;
		attempts = 0;
	}
	else {
		attempts++;
		if(attempts < 5)
			playRandomTheme();
		else {
			playDefaultTheme();
			settings::bEnableMTE = false;
			error("Could not find valid sound file in data/music/theme, disabling Multiple Themes...")
		}
	}
}

void playDefaultTheme() {
	@theme = playTrack("data/music/title.ogg", loop = false, pause = true);
	if(theme !is null) {
		theme.volume = 0;
		volume = 0;
		theme.paused = false;
		played = true;
	}
}

void tick(double time) {
	if(!soundEnabled)
		return;

	if(prevMusicVol != settings::dMusicVolume || prevSFXVol != settings::dSFXVolume || prevMasterVol != settings::dMasterVolume) {
		if(settings::dSFXVolume < 0.01)
		{
			musicVolume = settings::dMusicVolume;
			soundVolume = settings::dMasterVolume;
		}
		else {
			musicVolume = settings::dMusicVolume / settings::dSFXVolume;
			soundVolume = settings::dMasterVolume * settings::dSFXVolume;
		}

		prevMusicVol = settings::dMusicVolume;
		prevMasterVol = settings::dMasterVolume;
		prevSFXVol = settings::dSFXVolume;
	}
	
	if(game_running) {
		played = false;
		restartDelay = 5.0;
		if(theme !is null) {
			volume = max(0.0, volume - (time / 4.0));
			theme.volume = settings::dMusicVolume * settings::dMasterVolume * volume * themeVolume;
			if(volume <= 0.0) {
				theme.stop();
				@theme = null;
			}
		}
	}
	else {
		if(theme is null) {
			if(!played || settings::bLoopTheme) {
				restartDelay -= time;
				if(restartDelay <= 0.0) {
					restartDelay = 5.0;
					
					if(!settings::bEnableMTE) {}
						playDefaultTheme();
					}
					else {
						playRandomTheme();
					}
				}
			}
		}
		else if(theme.playing) {
			volume = min(1.0, volume + time);			
			theme.volume = musicVolume * volume * themeVolume;
		}
		else {
			@theme = null;
		}
	}
}