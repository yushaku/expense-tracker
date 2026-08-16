import { View, StyleSheet } from 'react-native';
import { Text } from 'react-native-paper';

export default function AddScreen() {
  return (
    <View style={styles.container}>
      <Text variant="titleMedium">Thêm chi tiêu</Text>
      <Text style={styles.hint}>Form sẽ thêm ở bước tiếp theo.</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 16, gap: 8 },
  hint: { opacity: 0.6 },
});
