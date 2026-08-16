// apps/mobile/app/index.tsx
import React, { useState, useEffect } from 'react';
import { View, FlatList, StyleSheet } from 'react-native';
import { FAB, Card, Text, Chip, IconButton } from 'react-native-paper';
import { Link, useRouter } from 'expo-router';
import { formatCurrency } from '@expense/shared';
import type { Expense } from '@expense/shared';

export default function HomeScreen() {
  const router = useRouter();
  const [expenses, setExpenses] = useState<Expense[]>([]);

  useEffect(() => {
    // TODO: Load from API/SQLite
    setExpenses([]);
  }, []);

  const renderExpense = ({ item }: { item: Expense }) => (
    <Card style={styles.card}>
      <Card.Content>
        <View style={styles.row}>
          <View style={styles.left}>
            <Text variant="titleMedium">{formatCurrency(item.amount, item.currency)}</Text>
            <Text variant="bodySmall">{new Date(item.date).toLocaleDateString('vi-VN')}</Text>
            {item.description ? <Text variant="bodyMedium">{item.description}</Text> : null}
          </View>
          <Chip mode="outlined">{item.category}</Chip>
        </View>
      </Card.Content>
    </Card>
  );

  return (
    <View style={styles.container}>
      <FlatList
        data={expenses}
        renderItem={renderExpense}
        keyExtractor={(item) => item.id}
        ListEmptyComponent={<Text style={styles.empty}>Chưa có chi tiêu nào.{'\n'}Nhấn + để thêm.</Text>}
      />
      <FAB icon="plus" style={styles.fab} onPress={() => router.push('/add')} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 16 },
  card: { marginBottom: 8 },
  row: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  left: { flex: 1 },
  fab: { position: 'absolute', right: 16, bottom: 16 },
  empty: { textAlign: 'center', marginTop: 48, opacity: 0.6 },
});
