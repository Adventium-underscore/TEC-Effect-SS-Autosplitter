/*
 * Current supported versions:
 * 2.0.1+
 */
state("TetrisEffect-Win64-Shipping") {}
state("TetrisEffect-WinGDK-Shipping") {}

// Find the game version when it launches
init {
	print("[TE:C Autosplitter] Game launch detected, initializing...");

	// Find a specific mov instruction that conveniently moves data to the base address we use
	var target = new SigScanTarget(3, "4C 8B 0D ????????", "45 33 FF")
								  {OnFound = (p, s, addr) => addr + 0x4 + p.ReadValue<int>(addr)};
	var baseAddr = new SignatureScanner(game, modules.First().BaseAddress, modules.First().ModuleMemorySize).Scan(target);
	if (baseAddr == IntPtr.Zero) throw new NullReferenceException();
	print("[TE:C Autosplitter] Found base offset " + (baseAddr.ToInt64() - modules.First().BaseAddress.ToInt64()).ToString("X"));
	// From this base offset, use pointer paths to find the values we need
	vars.watchers = new MemoryWatcherList {
		new MemoryWatcher<int>(new DeepPointer(baseAddr, 0x8, 0x800, 0xC0, 0x248, 0x0))
											  {Name = "PuzzleManager", FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull},
		new MemoryWatcher<byte>(new DeepPointer(baseAddr, 0x8, 0x800, 0xC0, 0x248, 0x0, 0x45C))
											   {Name = "PuzzleHaltReason", FailAction = MemoryWatcher.ReadFailAction.DontUpdate},
		new MemoryWatcher<int>(new DeepPointer(baseAddr, 0x8, 0x800, 0xC0, 0x258, 0x0, 0x3D0))
											  {Name = "PauseManager", FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull}
	};
	current.pauseRestart = false;
	print("[TE:C Autosplitter] Initialization complete.");
}

// Update variables and convert some to booleans
update {
	vars.watchers.UpdateAll(game);
	current.haltflag = vars.watchers["PuzzleHaltReason"].Current;
	
	current.ingame = (vars.watchers["PuzzleManager"].Current != 0);
	current.paused = (vars.watchers["PauseManager"].Current != 0);
}

// Start the timer when the game is loaded, not halted, and not paused
start {
	if(current.ingame && current.haltflag == 0 && !current.paused) {
		print("[TE:C Autosplitter] Timer started.");
		return true;
	}
}

// Split when the game unloads a mode
split {
	if(current.paused && (current.haltflag == 8 || current.haltflag == 10)) {
		current.pauseRestart = true;
	}
	
	if(!current.ingame && old.ingame) {
		if(current.pauseRestart) {
			current.pauseRestart = false;
		} else {
			print("[TE:C Autosplitter] Timer split.");
			return true;
		}
	}
}

// Pause the timer if the mode is unloaded (in-between modes), the game is paused, or the player doesn't have control
isLoading {
	if(!current.ingame || !old.ingame) {
		return true;
	} else if(current.haltflag == 2 || current.haltflag == 4 || current.haltflag == 8 || current.haltflag == 24) {
		return true;
	} else if(current.paused) {
		return true;
	} else {
		return false;
	}
}
