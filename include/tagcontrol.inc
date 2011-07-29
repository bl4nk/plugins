#if defined _tagcontrol_included
 #endinput
#endif
#define _tagcontrol_included

/**
 * @brief When a tag is being added
 *
 * @param		szTag	Tag being added
 * @return      Plugin_Continue to allow, Plugin_Handled to block
 */
forward Action:OnAddTag(const String:szTag[]);

/** Do Not Edit Below This Line **/
public Extension:__ext_tagcontrol =
{
	name = "tagcontrol",
	file = "tagcontrol.ext",
#if defined AUTOLOAD_EXTENSIONS
	autoload = 1,
#else
	autoload = 0,
#endif
#if defined REQUIRE_EXTENSIONS
	required = 1,
#else
	required = 0,
#endif
};
