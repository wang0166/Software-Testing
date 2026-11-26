package com.pandora.log.security;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import org.junit.jupiter.api.Test;
import com.pandora.log.common.BusinessException;

class PasswordPolicyTest {
    private final PasswordPolicy policy = new PasswordPolicy();

    @Test void acceptsRequiredCharacterClassesAndLongPasswords() {
        assertThatCode(() -> policy.validate("Secure!Pass123")).doesNotThrowAnyException();
        assertThatCode(() -> policy.validate("Aa1!" + "x".repeat(124))).doesNotThrowAnyException();
    }

    @Test void rejectsLengthMissingClassesWhitespaceAndCommonPasswords() {
        for (String value : new String[] {"Aa1!short", "lowercase123!", "UPPERCASE123!",
                "NoDigitsHere!", "NoSpecial123A", "Has Space123!A", "Password123!"}) {
            assertThatThrownBy(() -> policy.validate(value)).isInstanceOf(BusinessException.class);
        }
        assertThatThrownBy(() -> policy.validate("Aa1!" + "x".repeat(125)))
                .isInstanceOf(BusinessException.class);
    }
}
